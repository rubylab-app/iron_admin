# frozen_string_literal: true

module IronAdmin
  # Lightweight request context injected into Tool instances before action execution.
  #
  # Provides tools with access to request params, the current user, and flash messages
  # without coupling them to the controller.
  #
  # @example Accessing context in a tool action
  #   class ReportTool < IronAdmin::Tool
  #     tool_action :generate
  #
  #     def generate(ctx)
  #       user = ctx.current_user
  #       format = ctx.action_params(:format)[:format]
  #       ctx.flash[:notice] = "Report generated for #{user.name}"
  #     end
  #   end
  class ToolContext
    # @return [ActionController::Parameters] Raw request params
    attr_reader :params

    # @return [Object, nil] Current authenticated user
    attr_reader :current_user

    # @return [ActionDispatch::Flash::FlashHash] Flash messages
    attr_reader :flash

    # @param params [ActionController::Parameters]
    # @param current_user [Object, nil]
    # @param flash [ActionDispatch::Flash::FlashHash]
    def initialize(params:, current_user:, flash:)
      @params = params
      @current_user = current_user
      @flash = flash
    end

    # Extracts and permits only the specified keys from tool_action params.
    #
    # @param keys [Array<Symbol>] Keys to permit
    # @return [Hash] Permitted params as a symbolized hash
    def action_params(*keys)
      raw = params.fetch(:tool_action, {})
      return {} unless raw.respond_to?(:permit)

      raw.permit(*keys).to_h.symbolize_keys
    end
  end
end
