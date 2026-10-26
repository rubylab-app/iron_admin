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
      # @return [IronAdmin::Configuration::Theme] Theme configuration
      def theme
        IronAdmin.configuration.theme
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
        "block text-xs font-semibold uppercase tracking-wider #{theme.muted_text}"
      end

      # @api private
      # @return [String] CSS classes for select element
      def select_classes
        "block w-full appearance-none border px-3 py-2 text-sm shadow-sm outline-none " \
          "transition duration-150 ease-in-out #{theme.border_radius} #{theme.input_border} " \
          "#{theme.card_bg} #{theme.body_text} #{theme.input_focus}"
      end

      # @api private
      # @return [String] Inline CSS style for dropdown chevron
      def chevron_style
        "background-image: url(\"data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' " \
          "viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-linecap='round' stroke-linejoin='round' " \
          "stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e\"); background-position: right 0.5rem center; " \
          "background-repeat: no-repeat; background-size: 1.5em 1.5em; padding-right: 2.5rem;"
      end
    end
  end
end
