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
      new: :create,
      edit: :update,
      delete: :destroy,
    }.freeze

    # Reverse mapping from CRUD operations to controller actions.
    # @return [Hash{Symbol => Array<Symbol>}]
    REVERSE_ALIASES = ACTION_ALIASES.each_with_object({}) do |(action, crud), hash|
      (hash[crud] ||= []) << action
    end.freeze

    # Maps a controller or CRUD name to the stored CRUD action.
    #
    # @param action [Symbol, String]
    # @return [Symbol]
    def self.canonical_action(action)
      name = action.to_sym
      ACTION_ALIASES[name] || name
    end

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
      return false if denied?(action, user)

      permitted?(action, user)
    end

    # Checks if a custom action (or bulk action) is allowed.
    #
    # Unlike {#allowed?}, this does not use action aliases.
    # Custom actions are allowed by default unless explicitly restricted
    # via an `allow` rule with a condition. This separates custom action
    # authorization from CRUD policy — custom actions are not gated by
    # the CRUD allowlist.
    #
    # @param action_name [Symbol] The custom action name
    # @param user [Object] The current user object
    #
    # @return [Boolean] True if the action is allowed, or if no policy is configured,
    #   or if the action has no explicit rule
    #
    # @example
    #   policy.action_allowed?(:refund, current_user)
    def action_allowed?(action_name, user)
      return true unless @configured

      action = action_name.to_sym
      return false if denied?(action, user)
      return true unless @allow_rules.key?(action)

      condition = @allow_rules[action]
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
      return true if deny_rule_applies?(action, user)

      aliased_action = ACTION_ALIASES[action]
      return true if aliased_action && deny_rule_applies?(aliased_action, user)

      Array(REVERSE_ALIASES[action]).any? { |reverse_action| deny_rule_applies?(reverse_action, user) }
    end

    # A failing condition does not hide later alias rules.
    def permitted?(action, user)
      return true if allow_rule_matches?(action, user)

      aliased_action = ACTION_ALIASES[action]
      return true if aliased_action && allow_rule_matches?(aliased_action, user)

      Array(REVERSE_ALIASES[action]).any? { |reverse_action| allow_rule_matches?(reverse_action, user) }
    end

    def allow_rule_matches?(action, user)
      return false unless @allow_rules.key?(action)

      condition = @allow_rules[action]
      condition.nil? || condition.call(user)
    end

    def deny_rule_applies?(action, user)
      return false unless @deny_rules.key?(action)

      deny_rule_matches?(action, user)
    end

    def deny_rule_matches?(action, user)
      condition = @deny_rules[action]
      condition.nil? || condition.call(user)
    end
  end
end
