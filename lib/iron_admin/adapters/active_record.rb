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
        condition = model_class.with_connection { |conn| like_condition(conn, column, "?") }
        scope.where(condition, "%#{sanitize_like(query)}%")
      end

      def search_columns(scope, columns, query)
        conditions = model_class.with_connection do |conn|
          columns.map { |col| like_condition(conn, col, ":q") }
        end
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

      # Waits for every open transaction to commit, or runs the block at once
      # when none is open.
      def after_commit(&)
        ::ActiveRecord.after_all_transactions_commit(&)
      end

      # --- Batch ---

      # ActiveRecord's find_each drops ORDER BY and walks the primary key, so an
      # ordered scope is paged with LIMIT/OFFSET instead, keeping the index order.
      def find_each(scope, batch_size: 1000, &)
        return scope.find_each(batch_size: batch_size, &) if scope.order_values.empty?

        ordered = order_with_primary_key_tiebreak(scope)
        0.step(by: batch_size) do |offset|
          batch = ordered.limit(batch_size).offset(offset).to_a
          batch.each(&)
          break if batch.size < batch_size
        end
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

      # (see Base#pagy_method)
      def pagy_method
        :pagy
      end

      def cast_boolean(value)
        ::ActiveModel::Type::Boolean.new.cast(value)
      end

      private

      # Builds `"table"."column" LIKE|ILIKE <placeholder> ESCAPE '\'` with a
      # connection borrowed through `with_connection`, so search never calls
      # the soft-deprecated `ActiveRecord::Base.connection` (which raises when
      # a host sets `config.active_record.permanent_connection_checkout =
      # :disallowed`).
      def like_condition(conn, column, placeholder)
        table = conn.quote_table_name(model_class.table_name)
        operator = conn.adapter_name.downcase.include?("postgresql") ? "ILIKE" : "LIKE"
        "#{table}.#{conn.quote_column_name(column)} #{operator} #{placeholder} #{like_escape_clause}"
      end

      # OFFSET pages are only stable when the order is total.
      def order_with_primary_key_tiebreak(scope)
        keys = Array(primary_key).map(&:to_sym)
        keys.empty? ? scope : scope.order(*keys)
      end

      def like_escape_clause
        "ESCAPE '\\'"
      end

      def sanitize_like(value)
        value.to_s.gsub(/[%_\\]/) { |match| "\\#{match}" }
      end

      def eager_load_model_paths
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
