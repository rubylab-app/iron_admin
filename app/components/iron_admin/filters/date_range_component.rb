# frozen_string_literal: true

module IronAdmin
  module Filters
    # Renders a date range filter with from/to inputs.
    class DateRangeComponent < ViewComponent::Base
      # @return [Symbol] Filter name
      attr_reader :name

      # @return [String] Filter label
      attr_reader :label

      # @return [Date, nil] Start date value
      attr_reader :from_value

      # @return [Date, nil] End date value
      attr_reader :to_value

      # @param name [Symbol] Filter name
      # @param label [String, nil] Label text
      # @param from_value [Date, nil] Start date
      # @param to_value [Date, nil] End date
      def initialize(name:, label: nil, from_value: nil, to_value: nil)
        @name = name
        @label = label || name.to_s.humanize
        @from_value = from_value
        @to_value = to_value
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] Form field name for start date
      def from_field_name
        "filters[#{name}_from]"
      end

      # @api private
      # @return [String] Form field name for end date
      def to_field_name
        "filters[#{name}_to]"
      end

      # @api private
      # @return [String] DOM id of the start date input, which the label points at
      def from_field_id
        "filters_#{name}_from"
      end

      # @api private
      # @return [String] DOM id of the end date input
      def to_field_id
        "filters_#{name}_to"
      end

      # @api private
      # @return [String] CSS classes for label elements
      def label_classes
        ControlStyles.label(theme)
      end

      # @api private
      # @return [String] CSS classes for date input fields
      def input_classes
        ControlStyles.input(theme)
      end
    end
  end
end
