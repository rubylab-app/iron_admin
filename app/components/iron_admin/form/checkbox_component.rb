# frozen_string_literal: true

module IronAdmin
  module Form
    # Renders a checkbox input.
    #
    # @example Basic checkbox
    #   render IronAdmin::Form::CheckboxComponent.new(
    #     name: "record[active]",
    #     checked: @record.active,
    #     label: "Active"
    #   )
    class CheckboxComponent < ViewComponent::Base
      include Concerns::FormInputBehavior

      # @return [String] Checkbox name attribute
      attr_reader :name

      # @return [Boolean] Whether checkbox is checked
      attr_reader :checked

      # @return [String, nil] Label text
      attr_reader :label

      # @param name [String] Checkbox name
      # @param checked [Boolean] Checked state
      # @param label [String, nil] Label text
      # @param disabled [Boolean] Disabled state
      # @param field [IronAdmin::Field, nil] Field config
      # @param current_user [Object, nil] Current user
      def initialize(name:, checked: false, label: nil, disabled: false, field: nil, current_user: nil)
        @name = name
        @checked = checked
        @label = label
        @disabled = disabled
        @field = field
        @current_user = current_user
      end

      # @api private
      # @return [String] CSS classes for checkbox input, with the engine's check mark
      def checkbox_classes
        ControlClasses.checkbox(theme)
      end

      # @api private
      # @return [String] CSS classes for label text
      def label_classes
        "text-sm #{theme.body_text}"
      end
    end
  end
end
