# frozen_string_literal: true

module IronAdmin
  # Base controller for all IronAdmin admin panel controllers.
  #
  # Provides authentication and current user handling for the admin panel.
  # All other IronAdmin controllers inherit from this class.
  #
  # @see IronAdmin::Configuration#authenticate
  # @see IronAdmin::Configuration#current_user
  class ApplicationController < ::ActionController::Base
    include Pagy::Method

    before_action :authenticate_iron_admin_user!

    rescue_from IronAdmin::RecordNotFound, with: :render_not_found
    rescue_from ActionController::ParameterMissing, with: :render_bad_request

    helper_method :iron_admin_current_user, :iron_admin_filter_param, :iron_admin_active_filter?

    private

    # @api private
    def authenticate_iron_admin_user!
      return unless IronAdmin.configuration.authenticate_block

      instance_exec(self, &IronAdmin.configuration.authenticate_block)
    end

    # @api private
    def iron_admin_current_user
      return unless IronAdmin.configuration.current_user_block

      @iron_admin_current_user ||= instance_exec(self, &IronAdmin.configuration.current_user_block)
    end

    def iron_admin_filter_param(*keys)
      iron_admin_param_dig(params[:filters], *keys)
    end

    def iron_admin_active_filter?(filter)
      iron_admin_filter_param(filter[:name]).present? ||
        iron_admin_filter_param("#{filter[:name]}_from").present? ||
        iron_admin_filter_param("#{filter[:name]}_to").present? ||
        (iron_admin_filter_param(filter[:name].to_s).is_a?(ActionController::Parameters) &&
          iron_admin_filter_param(filter[:name].to_s, "value").present?)
    end

    def iron_admin_param_dig(value, *keys)
      keys.reduce(value) do |current, key|
        return nil unless current.is_a?(ActionController::Parameters) || current.is_a?(Hash)

        current[key]
      end
    end

    def render_not_found
      head(:not_found)
    end

    def render_bad_request
      head(:bad_request)
    end
  end
end
