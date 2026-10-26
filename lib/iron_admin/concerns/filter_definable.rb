# frozen_string_literal: true

module IronAdmin
  module Concerns
    # The filter DSL of {IronAdmin::Resource}: declared filters, filters
    # inferred from the schema, and how the two lists combine. Extracted to
    # keep Resource under the Metrics/ClassLength budget.
    module FilterDefinable
      extend ActiveSupport::Concern

      # Columns that never get an inferred filter.
      SKIP_FILTER_COLUMNS = %w[id created_at updated_at].freeze

      # Field types the UI never shows; a filter on one would let readers probe the value.
      SENSITIVE_FIELD_TYPES = %i[password hidden].freeze

      module FilterDsl
        # Defines an index filter. It replaces the auto-inferred filter of the same name.
        #
        # @param name [Symbol] The column or attribute to filter by
        # @param options [Hash] :type, :options, :label
        # @example
        #   filter :status, type: :select, options: %w[pending active]
        # @return [void]
        def filter(name, **options)
          self.defined_filters = defined_filters + [{ name: name, **options }]
        end

        # Removes a filter, whether declared or auto-inferred.
        #
        # @param name [Symbol] The filter name to remove
        # @example
        #   remove_filter :status
        # @return [void]
        def remove_filter(name)
          self.defined_filters = defined_filters.reject { |f| f[:name].to_sym == name.to_sym }
          self.removed_filter_names = removed_filter_names | [name.to_sym]
        end

        # @api private
        # Filters inferred from enums (:select), string/text columns (:string)
        # and numeric columns (:number). Removed filters and :password, :hidden
        # or never-visible fields get none.
        #
        # @return [Array<Hash>] Auto-generated filter configurations
        def auto_inferred_filters
          excluded = removed_filter_names + sensitive_field_names
          enum_filters = enum_auto_filters(excluded)
          enum_filters + infer_column_filters(excluded + enum_filters.pluck(:name))
        end

        # The auto-inferred filters, then the declared ones. A declared filter
        # replaces the auto-inferred filter of the same name.
        #
        # @return [Array<Hash>] All filter configurations
        def all_filters
          declared_names = defined_filters.map { |f| f[:name].to_sym }
          inferred = auto_inferred_filters.reject { |f| declared_names.include?(f[:name]) }
          inferred + defined_filters.map { |f| with_enum_options(f) }
        end

        private

        def sensitive_field_names
          field_overrides.filter_map do |name, options|
            name.to_sym if SENSITIVE_FIELD_TYPES.include?(options[:type]) || options[:visible] == false
          end
        end

        # A declared :select on an enum with no options of its own offers the enum values.
        def with_enum_options(filter)
          return filter unless filter[:type] == :select && !filter.key?(:options)

          values = adapter.enums[filter[:name].to_s]
          values ? filter.merge(options: values.keys) : filter
        end

        def enum_auto_filters(excluded)
          adapter.enums.filter_map do |name, values|
            next if excluded.include?(name.to_sym)

            { name: name.to_sym, type: :select, options: values.keys }
          end
        end

        def infer_column_filters(excluded)
          already_defined = excluded + defined_filters.map { |f| f[:name].to_sym }

          adapter.columns.filter_map do |col|
            next if already_defined.include?(col.name.to_sym)
            next if SKIP_FILTER_COLUMNS.include?(col.name)

            infer_filter_from_column(col)
          end
        end

        def infer_filter_from_column(col)
          case col.type
          when :string, :text
            { name: col.name.to_sym, type: :string, label: col.name.humanize }
          when :integer, :float, :decimal
            return nil if col.name.end_with?("_id")

            { name: col.name.to_sym, type: :number, label: col.name.humanize }
          end
        end
      end

      included do
        class_attribute :defined_filters, default: []
        class_attribute :removed_filter_names, default: []
      end

      class_methods do
        include FilterDsl
      end
    end
  end
end
