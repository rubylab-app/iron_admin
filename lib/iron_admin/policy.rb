# frozen_string_literal: true

module IronAdmin
  # Authorization policy for controlling access to resource actions.
  #
  # Policies define which actions users can perform on resources.
  # They use a simple DSL with `allow` and `deny` to manage permissions.
  #
  # When no policy is defined for a resource, all actions are allowed by default.
  # Once a policy block is provided, actions must be explicitly allowed.
  # Deny rules take precedence over allow rules.
  #
  # @example Basic policy in a resource
  #   class UserResource < IronAdmin::Resource
  #     policy do
  #       allow :read                           # Everyone can view
  #       allow :create, :update, if: ->(user) { user.admin? }
  #       deny :destroy                         # No one can delete
  #     end
  #   end
  #
  # @example Policy with conditional deny
  #   class OrderResource < IronAdmin::Resource
  #     policy do
  #       allow :read, :create, :update, :destroy
  #       deny :destroy, if: ->(user) { !user.superadmin? }
  #     end
  #   end
  #
  # @note Action aliases are supported:
  #   - `:show` and `:index` are aliases for `:read`
  #   - Allowing `:read` implicitly allows `:show` and `:index`
  #   - Allowing `:show` or `:index` is treated as allowing `:read`
  #
  # @see IronAdmin::Resource#policy
  class Policy
    # Maps controller actions to CRUD operations.
    # @return [Hash{Symbol => Symbol}]
    ACTION_ALIASES = {
      show: :read,
      index: :read,
    }.freeze

    # Reverse mapping from CRUD operations to controller actions.
    # @return [Hash{Symbol => Array<Symbol>}]
    REVERSE_ALIASES = ACTION_ALIASES.each_with_object({}) do |(action, crud), hash|
      (hash[crud] ||= []) << action
    end.freeze

    # Creates a new Policy instance.
    #
    # @yield Configuration block using the Policy DSL
    #
    # @example
    #   Policy.new do
    #     allow :read
    #     allow :update, if: ->(user) { user.admin? }
    #   end
    def initialize(&)
      @allow_rules = {}
      @deny_rules = {}
      @configured = block_given?
      instance_eval(&) if block_given?
    end

    # Grants permission for one or more actions.
    #
    # @param actions [Array<Symbol>] Action names to allow
    #   - CRUD actions: :read, :create, :update, :delete
    #   - Controller actions: :show, :index (aliased to :read)
    #   - Custom actions: any symbol matching a defined action
    # @param if [Proc, nil] Optional condition proc that receives the user
    #   and returns true if the action should be allowed
    #
    # @example Unconditional allow
    #   allow :read
    #
    # @example Conditional allow
    #   allow :update, :delete, if: ->(user) { user.admin? }
    #
    # @return [void]
    def allow(*actions, if: nil)
      condition = binding.local_variable_get(:if)
      actions.each { |action| @allow_rules[action] = condition }
    end

    # Denies permission for one or more actions.
    #
    # Deny rules take precedence over allow rules. If an action is both
    # allowed and denied, the deny rule wins.
    #
    # @param actions [Array<Symbol>] Action names to deny
    # @param if [Proc, nil] Optional condition proc that receives the user
    #   and returns true if the action should be denied
    #
    # @example Unconditional deny
    #   deny :destroy
    #
    # @example Conditional deny
    #   deny :destroy, if: ->(user) { !user.superadmin? }
    #
    # @return [void]
    def deny(*actions, if: nil)
      condition = binding.local_variable_get(:if)
      actions.each { |action| @deny_rules[action] = condition }
    end

    # Checks if a CRUD action is allowed for the given user.
    #
    # Handles action aliases automatically:
    # - If :show or :index is checked, also checks for :read permission
    # - If :read is checked, also checks for :show/:index permissions
    #
    # @param action [Symbol] The action to check (:read, :create, :update, :delete, :show, :index)
    # @param user [Object] The current user object passed to condition procs
    #
    # @return [Boolean] True if the action is allowed
    #
    # @example
    #   policy.allowed?(:read, current_user)  #=> true
    #   policy.allowed?(:show, current_user)  #=> true (alias for :read)
    def allowed?(action, user)
      return true unless @configured

      # Deny rules take precedence over allow rules
      return false if denied?(action, user)

      # Check the action directly first
      if @allow_rules.key?(action)
        condition = @allow_rules[action]
        return condition.nil? || condition.call(user)
      end

      # Check forward alias (e.g., :show -> :read)
      aliased_action = ACTION_ALIASES[action]
      if aliased_action && @allow_rules.key?(aliased_action)
        condition = @allow_rules[aliased_action]
        return condition.nil? || condition.call(user)
      end

      # Check reverse aliases (e.g., :read -> [:show, :index])
      reverse_actions = REVERSE_ALIASES[action]
      reverse_actions&.each do |reverse_action|
        next unless @allow_rules.key?(reverse_action)

        condition = @allow_rules[reverse_action]
        return condition.nil? || condition.call(user)
      end

      false
    end

    # Checks if a custom action (or bulk action) is allowed.
    #
    # Unlike {#allowed?}, this does not use action aliases.
    # Custom actions must be explicitly allowed by name.
    #
    # @param action_name [Symbol] The custom action name
    # @param user [Object] The current user object
    #
    # @return [Boolean] True if the action is allowed, or if no policy is configured
    #
    # @example
    #   policy.action_allowed?(:refund, current_user)
    def action_allowed?(action_name, user)
      return true unless @configured
      return false if denied?(action_name, user)
      return false unless @allow_rules.key?(action_name)

      condition = @allow_rules[action_name]
      condition.nil? || condition.call(user)
    end

    private

    # Checks if an action is denied for the given user.
    # Applies the same alias resolution as allowed? so that
    # deny :read also denies :show/:index and vice versa.
    #
    # @param action [Symbol] The action to check
    # @param user [Object] The current user object
    # @return [Boolean] True if the action is explicitly denied
    def denied?(action, user)
      # Check the action directly
      return deny_rule_matches?(action, user) if @deny_rules.key?(action)

      # Check forward alias (e.g., :show -> :read)
      aliased_action = ACTION_ALIASES[action]
      return deny_rule_matches?(aliased_action, user) if aliased_action && @deny_rules.key?(aliased_action)

      # Check reverse aliases (e.g., :read -> [:show, :index])
      REVERSE_ALIASES[action]&.each do |reverse_action|
        return deny_rule_matches?(reverse_action, user) if @deny_rules.key?(reverse_action)
      end

      false
    end

    def deny_rule_matches?(action, user)
      condition = @deny_rules[action]
      condition.nil? || condition.call(user)
    end
  end
end
