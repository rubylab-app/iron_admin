# frozen_string_literal: true

module IronAdmin
  module Dashboards
    # Renders a table of recent records on the dashboard.
    class RecentTableComponent < ViewComponent::Base
      include IronAdmin::ApplicationHelper
      include IronAdmin::FieldDisplayHelper
      include IronAdmin::ThemeHelper
      include Concerns::ThemedCard

      # Number of columns shown when the resource declares no index fields.
      DEFAULT_COLUMN_COUNT = 4

      # Columns the default selection places itself (id first, created_at last) or leaves out.
      FIXED_COLUMNS = %i[id created_at updated_at deleted_at].freeze

      # Field types too long or too sensitive for a compact table.
      SKIPPED_TYPES = %i[textarea rich_text markdown code json key_value boolean_group file files password hidden].freeze

      # Field types whose cells align their digits.
      NUMERIC_TYPES = %i[number currency].freeze

      # @param resource_name [Symbol, String] Resource name
      # @param records [ActiveRecord::Relation, Array] Records to display. An unordered
      #   relation is listed newest first.
      # @param current_user [Object, nil] Current user, for field visibility
      def initialize(resource_name:, records:, current_user: nil)
        @resource_name = resource_name
        @records = records
        @current_user = current_user
      end

      # @api private
      # @return [String] Humanized and pluralized resource label
      def label
        @resource_name.to_s.humanize.pluralize
      end

      # The columns to show: the resource's index fields when it declares them,
      # otherwise the id, label and other short columns, and the creation time.
      # Fields hidden from the current user are left out.
      #
      # @api private
      # @return [Array<IronAdmin::Field>]
      def fields
        @fields ||= begin
          resource_class = IronAdmin::ResourceRegistry.find(@resource_name.to_s.pluralize)
          resource_class ? columns_for(resource_class) : []
        end
      end

      # The records, newest first unless the relation already has an order.
      #
      # @api private
      # @return [Enumerable]
      def ordered_records
        return @records unless @records.respond_to?(:order_values) && @records.order_values.empty?

        order = recency_order(@records.klass)
        order.empty? ? @records : @records.order(order)
      end

      # @api private
      # @return [String, nil] Formatted field value for display
      def display_value(record, field)
        display_index_field_value(record, field)
      end

      # Case and letter spacing come from label_transform, as in every small label.
      #
      # @api private
      # @return [String] Classes of a header cell
      def header_cell_classes
        "#{theme.table_header_text} #{theme.label_transform} #{theme.table_cell_padding}"
      end

      # @api private
      # @param field [IronAdmin::Field] The cell's field
      # @return [String] Classes of a body cell; numeric cells align their digits
      def cell_classes(field)
        classes = "#{theme.table_cell_padding} #{theme.body_text}"
        NUMERIC_TYPES.include?(field.type) ? "#{classes} tabular-nums" : classes
      end

      # Delegate route helpers to the view context so included helpers work
      delegate :iron_admin, :main_app, to: :helpers

      private

      def columns_for(resource_class)
        visible = resource_class.resolved_fields.select { |field| field.visible?(@current_user) }
        names = resource_class.index_field_names
        return default_fields(visible) unless names

        by_name = visible.index_by(&:name)
        names.filter_map { |name| by_name[name] }
      end

      def default_fields(fields)
        by_name = fields.index_by(&:name)
        short = fields.reject { |field| FIXED_COLUMNS.include?(field.name) || SKIPPED_TYPES.include?(field.type) }
        # Stable sort: label columns (name, title, ...) first, then the rest in column order.
        short = short.sort_by.with_index { |field, index| [label_rank(field), index] }
        slots = DEFAULT_COLUMN_COUNT - by_name.values_at(:id, :created_at).compact.size

        [by_name[:id], *short.first(slots), by_name[:created_at]].compact
      end

      def label_rank(field)
        ApplicationHelper::DISPLAY_METHODS.index(field.name) || ApplicationHelper::DISPLAY_METHODS.size
      end

      def recency_order(model)
        columns = Array(model.primary_key)
        columns.unshift("created_at") if model.column_names.include?("created_at")
        columns.index_with(:desc)
      end
    end
  end
end
