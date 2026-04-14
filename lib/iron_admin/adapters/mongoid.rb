# frozen_string_literal: true

module IronAdmin
  module Adapters
    # Mongoid adapter — wraps Mongoid's APIs behind the standard adapter interface.
    #
    # This adapter enables IronAdmin to work with MongoDB-backed models.
    # It implements all abstract methods from Adapters::Base using Mongoid's
    # query interface, field introspection, and association reflection.
    #
    # @example Configuring a resource to use Mongoid
    #   class ArticleResource < IronAdmin::Resource
    #     self.adapter_class = :mongoid
    #   end
    class Mongoid < Base
      # Maps Mongoid field types (Ruby classes) to IronAdmin symbol types.
      MONGOID_TYPE_MAP = {
        String => :string,
        Integer => :integer,
        Float => :float,
        BigDecimal => :decimal,
        Date => :date,
        DateTime => :datetime,
        Time => :datetime,
        Hash => :json,
        Array => :text,
        Symbol => :string,
      }.freeze

      TRUTHY_VALUES = %w[true 1 yes].freeze

      # --- Schema Introspection ---

      def columns
        model_class.fields.values.map do |field|
          ColumnDescriptor.new(field.name, map_field_type(field))
        end
      end

      def column_names
        model_class.fields.keys
      end

      def has_column?(name) # rubocop:disable Naming/PredicatePrefix
        model_class.fields.key?(name.to_s)
      end

      def enums
        return model_class.defined_enums if model_class.respond_to?(:defined_enums)

        {}
      end

      def associations(kind = nil)
        wrappers = model_class.relations.values.map { |r| AssociationWrapper.new(r) }
        kind ? wrappers.select { |w| w.macro == kind } : wrappers
      end

      def association(name)
        relation = model_class.relations[name.to_s]
        relation ? AssociationWrapper.new(relation) : nil
      end

      def attachments
        {}
      end

      def rich_text_attributes
        []
      end

      # --- Naming ---

      def table_name
        model_class.collection_name.to_s
      end

      # --- Query Building ---

      delegate :all, to: :model_class

      def find(id)
        model_class.find(id)
      rescue StandardError => e
        raise IronAdmin::RecordNotFound, e.message if not_found_error?(e)

        raise
      end

      delegate :find_by, to: :model_class

      def filter(scope, column, value)
        case value
        when Array
          scope.in(column => value)
        when Range
          build_range_filter(scope, column, value)
        else
          scope.where(column => value)
        end
      end

      def order_by(scope, column, direction)
        scope.order_by(column => direction)
      end

      def limit(scope, max)
        scope.limit(max)
      end

      def preload(scope, association_names)
        scope.includes(*association_names)
      end

      def distinct_values(column)
        model_class.distinct(column).compact.sort
      end

      def pluck(scope, column)
        scope.pluck(column)
      end

      def count(scope = nil)
        (scope || all).count
      end

      # --- Search ---

      def search_column(scope, column, query)
        pattern = /#{Regexp.escape(query)}/i
        scope.where(column => pattern)
      end

      def search_columns(scope, columns, query)
        pattern = /#{Regexp.escape(query)}/i
        conditions = columns.map { |col| { col => pattern } }
        scope.any_of(*conditions)
      end

      # --- CRUD ---

      def build(attrs = {})
        model_class.new(attrs)
      end

      def save(record)
        record.save
      end

      def update(record, attrs)
        record.update(attrs)
      end

      def destroy!(record)
        record.destroy!
      end

      # --- Transactions ---

      def transaction
        yield
      end

      # --- Scope Manipulation ---

      def unscope_column(scope, column)
        key = column.to_s
        new_selector = scope.selector.reject { |k, _| k == key }
        new_scope = model_class.where(new_selector)
        new_scope = new_scope.order_by(scope.options[:sort]) if scope.options[:sort]
        new_scope
      end

      # --- Batch ---

      def find_each(scope, &)
        scope.batch_size(100).each(&)
      end

      # --- Adapter-Agnostic Interface ---

      def record_changes(record)
        record.previous_changes
      end

      def wrap_rollback
        yield
      rescue IronAdmin::Rollback
        # Silently absorb rollback — Mongoid transactions (if used)
        # are handled separately
        nil
      end

      def query_builder_class
        IronAdmin::Filters::MongoidQueryBuilder
      end

      def pagy_method
        :pagy_mongoid
      end

      def cast_boolean(value) # rubocop:disable Naming/PredicateMethod
        TRUTHY_VALUES.include?(value.to_s.downcase)
      end

      private

      def map_field_type(field)
        return :string if field.name == "_id"

        MONGOID_TYPE_MAP.fetch(field.type) { boolean_or_text(field.type) }
      end

      def build_range_filter(scope, column, range)
        conditions = {}
        conditions["$gte"] = range.begin if range.begin
        conditions["$lte"] = range.end if range.end
        scope.where(column.to_s => conditions)
      end

      def not_found_error?(error)
        error.class.name.include?("NotFound") ||
          error.class.name.include?("DocumentNotFound") ||
          error.message.include?("not found")
      end

      def boolean_or_text(type)
        return :boolean if boolean_type?(type)

        :text
      end

      def boolean_type?(type)
        type_name = type.respond_to?(:name) ? type.name.to_s : type.to_s
        type_name.include?("Boolean") || type == TrueClass || type == FalseClass
      end
    end
  end
end

require_relative "mongoid/column_descriptor"
require_relative "mongoid/association_wrapper"
require_relative "../filters/mongoid_query_builder"
