# frozen_string_literal: true

module IronAdmin
  module Form
    # Renders a text input field.
    #
    # @example Basic text input
    #   render IronAdmin::Form::TextInputComponent.new(name: "record[name]", value: @record.name)
    class TextInputComponent < ViewComponent::Base
      include Concerns::FormInputBehavior

      # @return [String] Input name attribute
      attr_reader :name

      # @return [String, nil] Current value
      attr_reader :value

      # @return [Symbol] Input type (:text, :email, :password, etc.)
      attr_reader :type

      # @return [String, nil] Placeholder text
      attr_reader :placeholder

      # @return [Boolean] Whether input is read-only
      attr_reader :readonly

      # @return [Boolean] Whether input has error state
      attr_reader :has_error

      # @param name [String] Input name
      # @param value [String, nil] Current value
      # @param type [Symbol] Input type (default: :text)
      # @param placeholder [String, nil] Placeholder
      # @param disabled [Boolean] Disabled state
      # @param readonly [Boolean] Read-only state
      # @param has_error [Boolean] Error state
      # @param field [IronAdmin::Field, nil] Field config
      # @param current_user [Object, nil] Current user for visibility checks
      def initialize(name:, value: nil, type: :text, placeholder: nil,
                     disabled: false, readonly: false, has_error: false,
                     field: nil, current_user: nil)
        @name = name
        @value = value
        @type = type
        @placeholder = placeholder || name.to_s.humanize
        @disabled = disabled
        @readonly = readonly
        @has_error = has_error
        @field = field
        @current_user = current_user
      end

      # @api private
      # @return [String] CSS classes for text input field
      def input_classes
        base = "block w-full border px-3 py-2 text-sm shadow-sm outline-none transition duration-150 ease-in-out " \
               "#{theme.border_radius} #{theme.input_border} #{theme.card_bg} #{theme.body_text} #{theme.input_focus}"
        base += " !border-red-400 focus:!border-red-500 focus:!ring-red-500/20" if has_error
        base += " bg-gray-50 cursor-not-allowed" if effectively_disabled? || readonly
        base
      end

      # Renders the text input.
      # @return [String] HTML content
      def call
        tag.input(
          type: type,
          name: name,
          id: name,
          value: value,
          placeholder: placeholder,
          disabled: effectively_disabled?,
          readonly: readonly,
          class: input_classes
        )
      end
    end
  end
end
