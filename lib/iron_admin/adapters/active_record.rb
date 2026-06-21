# frozen_string_literal: true

module IronAdmin
  module Adapters
    # ActiveRecord adapter — wraps AR's APIs behind the standard adapter interface.
    #
    # This is the default adapter used by all resources unless overridden.
    # It delegates to ActiveRecord's column introspection, reflection system,
    # query interface, and CRUD operations.
    class ActiveRecord < Base
      # --- Schema Introspection ---

      delegate :columns, to: :model_class

      delegate :column_names, to: :model_class

      delegate :primary_key, to: :model_class

      def has_column?(name) # rubocop:disable Naming/PredicatePrefix
        model_class.column_names.include?(name.to_s)
      end

      def enums
        return {} unless model_class.respond_to?(:defined_enums)

        model_class.defined_enums
      end

      def associations(kind = nil)
        if kind
          model_class.reflect_on_all_associations(kind)
        else
          model_class.reflect_on_all_associations
        end
      end

      def association(name)
        model_class.reflect_on_association(name)
      end

      def attachments
        return {} unless model_class.respond_to?(:attachment_reflections)

        model_class.attachment_reflections
      end

      def rich_text_attributes
        return [] unless model_class.respond_to?(:rich_text_association_names)

        model_class.rich_text_association_names
      end

      def polymorphic_inverse_classes(polymorphic_name)
        eager_load_model_paths

        application_record_descendants.filter_map do |klass|
          next if klass.abstract_class?
          next unless klass.base_class == klass

          klass if polymorphic_inverse?(klass, polymorphic_name)
        end
      end

      # --- Naming ---

      delegate :table_name, to: :model_class

      # --- Query Building ---

      delegate :all, to: :model_class

      def find(id)
        model_class.find(id)
      rescue ::ActiveRecord::RecordNotFound => e
        raise IronAdmin::RecordNotFound, e.message
      end

      delegate :find_by, to: :model_class

      def filter(scope, column, value)
        scope.where(column => value)
      end

      def order_by(scope, column, direction)
        scope.order(column => direction)
      end

      def limit(scope, max)
        scope.limit(max)
      end

      def preload(scope, association_names)
        scope.includes(*association_names)
      end

      def distinct_values(column)
        model_class.distinct.pluck(column).compact.sort
      end

      def pluck(scope, column)
        scope.pluck(column)
      end

      def count(scope = nil)
        scope ||= all
        scope.count
      end

      # --- Search ---

      def search_column(scope, column, query)
        table = quoted_table_name
        col = connection.quote_column_name(column)
        scope.where("#{table}.#{col} #{like_operator} ?", "%#{sanitize_like(query)}%")
      end

      def search_columns(scope, columns, query)
        table = quoted_table_name
        conditions = columns.map { |col| "#{table}.#{connection.quote_column_name(col)} #{like_operator} :q" }
        scope.where(conditions.join(" OR "), q: "%#{sanitize_like(query)}%")
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

      # --- Scope Manipulation ---

      def unscope_column(scope, column)
        scope.unscope(where: column.to_sym)
      end

      # --- Transactions ---

      def transaction(&)
        ::ActiveRecord::Base.transaction(&)
      end

      # --- Batch ---

      def find_each(scope, &)
        scope.find_each(&)
      end

      # --- Adapter-Agnostic Interface ---

      def record_changes(record)
        record.saved_changes
      end

      def wrap_rollback
        yield
      rescue IronAdmin::Rollback
        raise ::ActiveRecord::Rollback
      end

      def query_builder_class
        IronAdmin::Filters::ActiveRecordQueryBuilder
      end

      def pagy_method
        :pagy
      end

      def cast_boolean(value)
        ::ActiveModel::Type::Boolean.new.cast(value)
      end

      private

      def connection
        model_class.connection
      end

      def quoted_table_name
        connection.quote_table_name(model_class.table_name)
      end

      def postgresql?
        connection.adapter_name.downcase.include?("postgresql")
      end

      def like_operator
        postgresql? ? "ILIKE" : "LIKE"
      end

      def sanitize_like(value)
        value.to_s.gsub(/[%_\\]/) { |match| "\\#{match}" }
      end

      def eager_load_model_paths
        return unless defined?(::Rails) && ::Rails.respond_to?(:autoloaders)

        Array(::Rails.application.config.eager_load_paths).each do |path|
          next unless path.to_s.end_with?("/app/models")
          next unless File.directory?(path)

          ::Rails.autoloaders.main.eager_load_dir(path)
        end
      end

      def application_record_descendants
        return [] unless defined?(::ApplicationRecord)

        ::ApplicationRecord.descendants
      end

      def polymorphic_inverse?(klass, polymorphic_name)
        %i[has_many has_one].any? do |macro|
          klass.reflect_on_all_associations(macro).any? do |reflection|
            reflection.options[:as]&.to_sym == polymorphic_name.to_sym
          end
        end
      end
    end
  end
end
