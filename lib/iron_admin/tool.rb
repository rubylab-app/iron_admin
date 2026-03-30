# frozen_string_literal: true

module IronAdmin
  # Base class for admin tools (custom pages in the admin panel).
  #
  # Tools are standalone pages that don't map to a database model.
  # External gems can subclass Tool to add custom admin functionality.
  #
  # @example Simple tool with declarative actions
  #   class CacheManagerTool < IronAdmin::Tool
  #     menu icon: "server", label: "Cache Manager", group: "System"
  #
  #     tool_action :clear_all, icon: "trash", confirm: true
  #     tool_action :flush_key,
  #       form_fields: [{ name: :cache_key, type: :text, required: true }]
  #
  #     def clear_all(ctx)
  #       Rails.cache.clear
  #       ctx.flash[:notice] = "Cache cleared!"
  #     end
  #
  #     def flush_key(ctx)
  #       key = ctx.action_params(:cache_key)[:cache_key]
  #       Rails.cache.delete(key)
  #     end
  #   end
  class Tool
    class_attribute :menu_options, default: {}
    class_attribute :defined_tool_actions, default: []

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
