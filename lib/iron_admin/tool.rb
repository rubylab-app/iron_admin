# frozen_string_literal: true

module IronAdmin
  # Base class for admin tools (custom pages in the admin panel).
  #
  # Tools are standalone pages that don't map to a database model.
  # External gems can subclass Tool to add custom admin functionality.
  #
  # Declare every action with {.tool_action}. A tool that declares one or more
  # actions, including actions inherited from a parent tool, dispatches only
  # those names: a POST to any other name returns 404 and does not call the
  # method, even when the tool defines that method. Helpers that are not
  # actions should be private.
  #
  # A tool that declares no actions, and inherits none, still dispatches its
  # own public methods.
  # That fallback is deprecated and removed in 1.0. Each dispatch warns once
  # per tool class and method through {IronAdmin.deprecator}. Set
  # +config.strict_tool_actions+ to turn the fallback off for every tool.
  #
  # @example Simple tool with declarative actions
  #   module IronAdmin
  #     module Tools
  #       class CacheManagerTool < IronAdmin::Tool
  #         menu icon: "server", label: "Cache Manager", group: "System"
  #
  #         tool_action :clear_all, icon: "trash", confirm: true
  #         tool_action :flush_key,
  #           form_fields: [{ name: :cache_key, type: :text, required: true }]
  #
  #         def clear_all(ctx)
  #           Rails.cache.clear
  #           ctx.flash[:notice] = "Cache cleared!"
  #         end
  #
  #         def flush_key(ctx)
  #           key = ctx.action_params(:cache_key)[:cache_key]
  #           Rails.cache.delete(key)
  #         end
  #       end
  #     end
  #   end
  class Tool
    class_attribute :menu_options, default: {}
    class_attribute :defined_tool_actions, default: []
    class_attribute :access_condition, default: nil

    # @return [ToolContext, nil] Request context, set by ToolsController before action execution
    attr_accessor :context

    class << self
      def inherited(subclass)
        super
        subclass.defined_tool_actions = defined_tool_actions.dup
        return if subclass.name.nil?

        begin
          IronAdmin::ToolRegistry.register(subclass)
        rescue NameError
          # ToolRegistry may not be loaded yet during boot
        end
      end

      # Declares a tool action with metadata.
      #
      # @param name [Symbol] Method name to call when action is executed
      # @param options [Hash] Action options passed to ToolAction.new
      # @option options [String] :label Display label
      # @option options [String] :icon Heroicon name
      # @option options [Boolean] :confirm Show confirmation dialog
      # @option options [String] :confirm_message Custom confirmation text
      # @option options [Array<Hash, ActionField>] :form_fields Fields to collect before execution
      # @option options [Proc] :condition Proc receiving user, returns boolean
      def tool_action(name, **)
        self.defined_tool_actions = defined_tool_actions + [ToolAction.new(name: name, **)]
      end

      # Restricts who may open this tool and run its actions.
      #
      # The condition receives the current user. A truthy value allows; +nil+
      # and +false+ deny with 403. It guards the tool page, every action and
      # action form, and the legacy dispatch of undeclared methods, and the
      # sidebar hides the tool from users it denies. An action's own
      # +condition:+ still applies on top of it. Subclasses inherit it.
      # Without it, {Configuration#default_policy} decides.
      #
      # @param condition [#call, nil] a callable that takes the user
      # @yieldparam user [Object, nil] the current user, when given a block
      # @raise [ArgumentError] when neither a callable nor a block is given
      # @return [void]
      # @example
      #   tool_access ->(user) { user&.admin? }
      def tool_access(condition = nil, &block)
        condition ||= block
        raise ArgumentError, "tool_access needs a callable or a block" unless condition.respond_to?(:call)

        self.access_condition = condition
      end

      # Whether +user+ may open this tool and run its actions.
      #
      # @param user [Object, nil]
      # @return [Boolean]
      def accessible_by?(user)
        return IronAdmin.configuration.default_allow? if access_condition.nil?

        access_condition.call(user) ? true : false
      end

      # Finds a declared tool action by name.
      #
      # @param name [Symbol, String] Action name
      # @return [ToolAction, nil]
      def find_tool_action(name)
        defined_tool_actions.find { |a| a.name == name.to_sym }
      end

      def menu(**options)
        self.menu_options = options
      end

      def tool_name
        name.sub(/Tool\z/, "").demodulize.underscore
      end

      def label
        menu_options[:label] || tool_name.humanize
      end
    end
  end
end
