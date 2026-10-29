# frozen_string_literal: true

module IronAdmin
  module Filters
    # Renders a select dropdown filter.
    class SelectFilterComponent < ViewComponent::Base
      # @return [Symbol] Filter name
      attr_reader :name

      # @return [String] Filter label
      attr_reader :label

      # @return [Array] Available options
      attr_reader :options

      # @return [String, nil] Currently selected value
      attr_reader :selected

      # @param name [Symbol] Filter name
      # @param options [Array] Available options
      # @param label [String, nil] Label text
      # @param selected [String, nil] Selected value
      def initialize(name:, options:, label: nil, selected: nil)
        @name = name
        @label = label || name.to_s.humanize
        @options = options
        @selected = selected
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] Form field name
      def field_name
        "filters[#{name}]"
      end

      # @api private
      # @return [String] DOM id of the select, which the label points at
      def field_id
        "filters_#{name}"
      end

      # @api private
      # @return [String] CSS classes for label elements
      def label_classes
        ControlStyles.label(theme)
      end

      # @api private
      # @return [String] CSS classes for select element, chevron included
      def select_classes
        ControlStyles.select(theme)
      end
    end
  end
end
