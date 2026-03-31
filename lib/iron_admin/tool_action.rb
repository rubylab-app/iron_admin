# frozen_string_literal: true

module IronAdmin
  # Value object representing a declared action on a Tool.
  #
  # Stores action metadata: display label, icon, confirmation settings,
  # form fields to collect before execution, and authorization condition.
  #
  # @example
  #   ToolAction.new(
  #     name: :run_task,
  #     label: "Run Task",
  #     icon: "play",
  #     confirm: true,
  #     form_fields: [{ name: :task_name, type: :select, options: %w[db:migrate db:seed] }],
  #     condition: ->(user) { user.admin? }
  #   )
  class ToolAction
    # @return [Symbol] Action method name
    attr_reader :name

    # @return [String] Display label
    attr_reader :label

    # @return [String, nil] Heroicon name
    attr_reader :icon

    # @return [Boolean] Whether to show confirmation dialog
    attr_reader :confirm

    # @return [String, nil] Custom confirmation message
    attr_reader :confirm_message

    # @return [Array<ActionField>] Form fields to collect before execution
    attr_reader :form_fields

    # @return [Proc, nil] Condition proc that receives current_user, returns boolean
    attr_reader :condition

    def initialize(name:, label: nil, icon: nil, confirm: false, confirm_message: nil, form_fields: [], condition: nil)
      @name = name.to_sym
      @label = label || name.to_s.humanize
      @icon = icon
      @confirm = confirm
      @confirm_message = confirm_message
      @form_fields = coerce_form_fields(form_fields)
      @condition = condition
    end

    # @return [Boolean] Whether this action has form fields to collect
    def has_form? # rubocop:disable Naming/PredicatePrefix
      form_fields.any?
    end

    # Checks if the action is allowed for the given user.
    #
    # @param user [Object, nil] Current user
    # @return [Boolean]
    def allowed?(user)
      return true if condition.nil?

      condition.call(user)
    end

    private

    def coerce_form_fields(fields)
      Array(fields).map do |f|
        f.is_a?(ActionField) ? f : ActionField.new(**f)
      end
    end
  end
end
