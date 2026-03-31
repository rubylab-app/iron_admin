# frozen_string_literal: true

module IronAdmin
  # Controller for rendering and executing admin tools.
  #
  # Supports both legacy bare-method tools and enhanced tools with
  # tool_action declarations, context injection, and authorization.
  class ToolsController < ApplicationController
    before_action :set_tool

    def show
      tool_template = "iron_admin/tools/#{@tool_class.tool_name}/show"
      render tool_template if lookup_context.exists?(tool_template)
    end

    def execute
      action_name = params[:action_name]
      declared = @tool_class.find_tool_action(action_name)

      if declared
        return head(:forbidden) unless declared.allowed?(iron_admin_current_user)
        return unless run_tool_action(declared)
      elsif @tool_class.method_defined?(action_name)
        run_legacy_action(action_name)
      else
        return head(:not_found)
      end

      redirect_to tool_path(@tool_class.tool_name)
    end

    # Renders the form for a tool action with form_fields.
    def action_form
      @declared_action = @tool_class.find_tool_action(params[:action_name])
      return head(:not_found) unless @declared_action&.has_form?
      return head(:forbidden) unless @declared_action.allowed?(iron_admin_current_user)

      @form_fields = @declared_action.form_fields
      @form_url = tool_action_path(@tool_class.tool_name, @declared_action.name)
    end

    private

    def set_tool
      @tool_class = ToolRegistry.find(params[:tool_name])
      head(:not_found) and return unless @tool_class
    end

    def run_tool_action(declared)
      unless @tool_class.method_defined?(declared.name)
        head(:not_found)
        return nil
      end

      tool_instance = build_tool_instance
      dispatch_with_arity(tool_instance, declared.name)
      true
    end

    def run_legacy_action(action_name)
      tool_instance = build_tool_instance
      dispatch_with_arity(tool_instance, action_name)
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
