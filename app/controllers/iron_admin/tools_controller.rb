# frozen_string_literal: true

module IronAdmin
  # Controller for rendering and executing admin tools.
  #
  # A tool with one or more actions declared with +tool_action+ dispatches only
  # those. A tool that declares none, and inherits none, still dispatches its own public methods.
  # That fallback is deprecated and removed in 1.0. +config.strict_tool_actions+
  # turns it off. Declared actions support context injection and authorization.
  class ToolsController < ApplicationController
    @legacy_dispatch_mutex = Mutex.new
    @legacy_dispatch_warnings = {}

    class << self
      # @api private
      def with_legacy_dispatch_warning(tool_class, method_name)
        key = [tool_class, method_name.to_sym]
        @legacy_dispatch_mutex.synchronize do
          unless @legacy_dispatch_warnings[key]
            yield
            @legacy_dispatch_warnings[key] = true
          end
        end
      end

      # Forgets warned legacy dispatches so a later one warns again.
      # Pairs are stored only after +warn+ returns, under a mutex.
      # @api private
      def reset_legacy_dispatch_warnings!
        @legacy_dispatch_mutex.synchronize { @legacy_dispatch_warnings = {} }
      end
    end

    before_action :set_tool

    def show
      tool_template = "iron_admin/tools/#{@tool_class.tool_name}/show"
      render tool_template if lookup_context.exists?(tool_template)
    end

    def execute
      action_name = params[:action_name]
      declared = @tool_class.find_tool_action(action_name)

      if declared
        return render_forbidden unless declared.allowed?(iron_admin_current_user)
        return unless run_tool_action(declared)
      elsif legacy_fallback?(action_name)
        run_legacy_action(action_name)
      else
        return render_not_found
      end

      redirect_to tool_path(@tool_class.tool_name)
    end

    # Renders the form for a tool action with form_fields.
    def action_form
      @declared_action = @tool_class.find_tool_action(params[:action_name])
      return render_not_found unless @declared_action&.has_form?
      return render_forbidden unless @declared_action.allowed?(iron_admin_current_user)

      @form_fields = @declared_action.form_fields
      @form_url = tool_action_path(@tool_class.tool_name, @declared_action.name)
    end

    private

    def set_tool
      @tool_class = ToolRegistry.find(params.expect(:tool_name))
      render_not_found unless @tool_class
    end

    def own_tool_method?(action_name)
      @tool_class.public_method_defined?(action_name.to_sym, false)
    end

    # Legacy tools declare no actions. Mixed tools and +strict_tool_actions+ do not use this.
    def legacy_fallback?(action_name)
      return false if IronAdmin.configuration.strict_tool_actions
      return false unless @tool_class.defined_tool_actions.empty?

      own_tool_method?(action_name)
    end

    def run_tool_action(declared)
      unless @tool_class.method_defined?(declared.name)
        render_not_found
        return nil
      end

      tool_instance = build_tool_instance
      dispatch_with_arity(tool_instance, declared.name)
      true
    end

    def run_legacy_action(action_name)
      warn_legacy_dispatch(action_name)
      tool_instance = build_tool_instance
      dispatch_with_arity(tool_instance, action_name)
    end

    def warn_legacy_dispatch(action_name)
      method_name = action_name.to_sym
      callstack = caller_locations(1)
      ToolsController.with_legacy_dispatch_warning(@tool_class, method_name) do
        IronAdmin.deprecator.warn(
          "#{@tool_class.name}##{method_name} was dispatched without a tool_action declaration. " \
          "Declare it, and every other method this tool dispatches, with tool_action: " \
          "a tool that declares one action dispatches only declared actions. " \
          "Dispatching undeclared methods is removed in 1.0.",
          callstack
        )
      end
    end

    def build_tool_instance
      tool = @tool_class.new
      tool.context = build_context
      tool
    end

    def dispatch_with_arity(tool_instance, method_name)
      if tool_instance.method(method_name).arity.zero?
        tool_instance.public_send(method_name)
      else
        tool_instance.public_send(method_name, tool_instance.context)
      end
    end

    def build_context
      ToolContext.new(
        params: params,
        current_user: iron_admin_current_user,
        flash: flash
      )
    end
  end
end
