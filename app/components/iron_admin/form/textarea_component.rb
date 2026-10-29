# frozen_string_literal: true

module IronAdmin
  module Form
    # Renders a textarea field.
    #
    # @example Basic textarea
    #   render IronAdmin::Form::TextareaComponent.new(
    #     name: "record[description]",
    #     value: @record.description,
    #     rows: 6
    #   )
    class TextareaComponent < ViewComponent::Base
      include Concerns::FormInputBehavior

      # @return [String] Textarea name attribute
      attr_reader :name

      # @return [String, nil] Current value
      attr_reader :value

      # @return [Integer] Number of rows
      attr_reader :rows

      # @return [String, nil] Placeholder text
      attr_reader :placeholder

      # @return [Boolean] Whether textarea is read-only
      attr_reader :readonly

      # @return [Boolean] Whether textarea has error state
      attr_reader :has_error

      # @param name [String] Textarea name
      # @param value [String, nil] Current value
      # @param rows [Integer] Number of rows (default: 4)
      # @param placeholder [String, nil] Placeholder
      # @param disabled [Boolean] Disabled state
      # @param readonly [Boolean] Read-only state
      # @param has_error [Boolean] Error state
      # @param field [IronAdmin::Field, nil] Field config
      # @param current_user [Object, nil] Current user
      def initialize(name:, value: nil, rows: 4, placeholder: nil,
                     disabled: false, readonly: false, has_error: false,
                     field: nil, current_user: nil)
        @name = name
        @value = value
        @rows = rows
        @placeholder = placeholder || name.to_s.humanize
        @disabled = disabled
        @readonly = readonly
        @has_error = has_error
        @field = field
        @current_user = current_user
      end

      # @api private
      # @return [String] CSS classes for textarea element
      def textarea_classes
        ControlClasses.textarea(theme, error: has_error, muted: effectively_disabled? || readonly)
      end

      # Renders the textarea.
      # @return [String] HTML content
      def call
        tag.textarea(
          value,
          name: name,
          id: name,
          rows: rows,
          placeholder: placeholder,
          disabled: effectively_disabled?,
          readonly: readonly,
          class: textarea_classes
        )
      end
    end
  end
end
