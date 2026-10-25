# frozen_string_literal: true

module IronAdmin
  module Form
    # Renders a date/time picker input.
    #
    # @example Date picker
    #   render IronAdmin::Form::DatePickerComponent.new(
    #     name: "record[birth_date]",
    #     value: @record.birth_date,
    #     type: :date
    #   )
    class DatePickerComponent < ViewComponent::Base
      # @return [String] Input name attribute
      attr_reader :name

      # @return [Date, DateTime, nil] Current value
      attr_reader :value

      # @return [Symbol] Picker type (:date, :datetime, :datetime_local, :time)
      attr_reader :type

      # @return [Date, nil] Minimum date
      attr_reader :min

      # @return [Date, nil] Maximum date
      attr_reader :max

      # @return [Boolean] Whether input is disabled
      attr_reader :disabled

      # @return [Boolean] Whether input has error state
      attr_reader :has_error

      # Supported date/time types.
      # @return [Array<Symbol>]
      TYPES = %i[date datetime datetime_local time].freeze

      # @param name [String] Input name
      # @param value [Date, DateTime, nil] Current value
      # @param type [Symbol] Picker type (default: :datetime_local)
      # @param min [Date, nil] Minimum date
      # @param max [Date, nil] Maximum date
      # @param disabled [Boolean] Disabled state
      # @param has_error [Boolean] Error state
      def initialize(name:, value: nil, type: :datetime_local, min: nil, max: nil,
                     disabled: false, has_error: false)
        @name = name
        @value = value
        @type = type.to_sym
        @min = min
        @max = max
        @disabled = disabled
        @has_error = has_error
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme configuration
      def theme
        IronAdmin.configuration.theme
      end

      # @api private
      # @return [String] HTML input type attribute value
      def input_type
        case @type
        when :datetime_local then "datetime-local"
        when :datetime then "datetime-local"
        else @type.to_s
        end
      end

      # @api private
      # @return [String] CSS classes for date input field
      def input_classes
        base = "block w-full border px-3 py-2 text-sm shadow-sm outline-none transition duration-150 ease-in-out " \
               "#{theme.border_radius} #{theme.input_border} #{theme.card_bg} #{theme.body_text} #{theme.input_focus}"
        base += " !border-red-400 focus:!border-red-500 focus:!ring-red-500/20" if has_error
        base += " bg-gray-50 cursor-not-allowed" if disabled
        base
      end

      # @api private
      # @return [String, nil] Value formatted for HTML input
      def formatted_value
        return nil unless value

        case @type
        when :date
          value.respond_to?(:strftime) ? value.strftime("%Y-%m-%d") : value
        when :datetime, :datetime_local
          value.respond_to?(:strftime) ? value.strftime("%Y-%m-%dT%H:%M") : value
        when :time
          value.respond_to?(:strftime) ? value.strftime("%H:%M") : value
        else
          value
        end
      end

      # Renders the date picker input.
      # @return [String] HTML content
      def call
        tag.input(
          type: input_type,
          name: name,
          id: name,
          value: formatted_value,
          min: min,
          max: max,
          disabled: disabled,
          class: input_classes
        )
      end
    end
  end
end
