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
      # @return [String] CSS classes for select element, with the engine's chevron
      def select_classes
        ControlClasses.select(theme, error: has_error, muted: effectively_disabled?)
      end
    end
  end
end
