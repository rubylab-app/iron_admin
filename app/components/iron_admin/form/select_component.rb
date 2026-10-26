# frozen_string_literal: true

module IronAdmin
  # Form components for rendering input fields.
  module Form
    # Renders a select dropdown field.
    #
    # @example Basic select
    #   render IronAdmin::Form::SelectComponent.new(
    #     name: "record[status]",
    #     options: %w[pending active completed],
    #     selected: @record.status
    #   )
    class SelectComponent < ViewComponent::Base
      include Concerns::FormInputBehavior

      # @return [String] Select name attribute
      attr_reader :name

      # @return [Array] Available options
      attr_reader :options

      # @return [String, nil] Currently selected value
      attr_reader :selected

      # @return [String, nil] Blank option text
      attr_reader :include_blank

      # @return [Boolean] Whether input has error state
      attr_reader :has_error

      # @param name [String] Select name
      # @param options [Array] Available options
      # @param selected [String, nil] Selected value
      # @param include_blank [String, nil] Blank option text
      # @param disabled [Boolean] Disabled state
      # @param has_error [Boolean] Error state
      # @param field [IronAdmin::Field, nil] Field config
      # @param current_user [Object, nil] Current user
      def initialize(name:, options:, selected: nil, include_blank: nil,
                     disabled: false, has_error: false, field: nil, current_user: nil)
        @name = name
        @options = options
        @selected = selected
        @include_blank = include_blank
        @disabled = disabled
        @has_error = has_error
        @field = field
        @current_user = current_user
      end

      # @api private
      # @return [String] CSS classes for select element
      def select_classes
        base = "block w-full appearance-none border px-3 py-2 text-sm shadow-sm outline-none " \
               "transition duration-150 ease-in-out #{theme.border_radius} #{theme.input_border} " \
               "#{theme.card_bg} #{theme.body_text} #{theme.input_focus}"
        base += " !border-red-400 focus:!border-red-500 focus:!ring-red-500/20" if has_error
        base += " bg-gray-50 cursor-not-allowed" if effectively_disabled?
        base
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
