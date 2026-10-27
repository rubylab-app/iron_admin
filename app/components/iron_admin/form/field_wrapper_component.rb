# frozen_string_literal: true

module IronAdmin
  module Form
    # Wraps form fields with label, error messages, and hints.
    #
    # @example Basic field wrapper
    #   render IronAdmin::Form::FieldWrapperComponent.new(name: :email, errors: @record.errors[:email]) do
    #     render IronAdmin::Form::TextInputComponent.new(name: "record[email]")
    #   end
    class FieldWrapperComponent < ViewComponent::Base
      # @return [Symbol, String] Field name
      attr_reader :name

      # @return [String, nil] Label text
      attr_reader :label

      # @return [Array<String>] Error messages
      attr_reader :errors

      # @return [Boolean] Whether field is required
      attr_reader :required

      # @return [String, nil] Hint text
      attr_reader :hint

      # @return [Boolean] Whether to span full width
      attr_reader :span_full

      # @param name [Symbol, String] Field name
      # @param label [String, nil] Label text
      # @param errors [Array<String>] Error messages
      # @param required [Boolean] Required state
      # @param hint [String, nil] Hint text
      # @param span_full [Boolean] Span full width
      def initialize(name:, label: nil, errors: [], required: false, hint: nil, span_full: false)
        @name = name
        @label = label || name.to_s.humanize
        @errors = Array(errors)
        @required = required
        @hint = hint
        @span_full = span_full
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [Boolean] Whether there are validation errors
      def has_errors?
        errors.any?
      end

      # @api private
      # @return [String] CSS classes for wrapper element
      def wrapper_classes
        span_full ? "md:col-span-2 2xl:col-span-3" : ""
      end

      # @api private
      # @return [String] CSS classes for label element
      def label_classes
        "block text-sm font-medium #{theme.label_text} mb-1.5"
      end

      # @api private
      # @return [String] CSS classes for error container
      def error_classes
        "flex items-center gap-1.5 mt-1.5"
      end
    end
  end
end
