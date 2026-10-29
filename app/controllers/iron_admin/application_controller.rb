# frozen_string_literal: true

module IronAdmin
  # Base controller for all IronAdmin admin panel controllers.
  #
  # Provides theme resolution, authentication and current user handling for the
  # admin panel. All other IronAdmin controllers inherit from this class.
  #
  # @see IronAdmin::Configuration#authenticate
  # @see IronAdmin::Configuration#current_user
  class ApplicationController < ::ActionController::Base
    include Pagy::Method

    # Before authentication, so pages and redirects it renders use the request's theme.
    before_action :resolve_iron_admin_theme
    before_action :authenticate_iron_admin_user!

    rescue_from IronAdmin::RecordNotFound, with: :render_not_found
    rescue_from ActionController::ParameterMissing, with: :render_bad_request

    helper_method :iron_admin_current_user, :iron_admin_filter_param, :iron_admin_active_filter?
    helper_method :iron_admin_error_navigation?

    private

    # @api private
    def resolve_iron_admin_theme
      IronAdmin::RequestContext.theme = IronAdmin.configuration.resolve_theme(request)
    end

    # Only an exact false from the block denies access, with 403. nil and any
    # other value allow the request. A redirect or render from the block is kept.
    # @api private
    def authenticate_iron_admin_user!
      return unless IronAdmin.configuration.authenticate_block

      result = instance_exec(self, &IronAdmin.configuration.authenticate_block)
      return if performed?

      render_authentication_denied if result.equal?(false)
    end

    # @api private
    def iron_admin_current_user
      return unless IronAdmin.configuration.current_user_block

      @iron_admin_current_user ||= instance_exec(self, &IronAdmin.configuration.current_user_block)
    end

    def iron_admin_filter_param(*keys)
      iron_admin_param_dig(params[:filters], *keys)
    end

    # String and number filters always submit their operator, so like Filterable
    # they count only when their value is filled in.
    def iron_admin_active_filter?(filter)
      name = filter[:name].to_s
      value = iron_admin_filter_param(name)
      return value["value"].present? if value.is_a?(ActionController::Parameters)

      value.present? ||
        iron_admin_filter_param("#{name}_from").present? ||
        iron_admin_filter_param("#{name}_to").present?
    end

    def iron_admin_param_dig(value, *keys)
      keys.reduce(value) do |current, key|
        return nil unless current.is_a?(ActionController::Parameters) || current.is_a?(Hash)

        current[key]
      end
    end

    def render_not_found
      render_error_page(:not_found)
    end

    def render_forbidden
      render_error_page(:forbidden)
    end

    # The admin shell asks every resource whether the visitor may read it.
    # A condition such as `user.admin?` raises when that visitor is nil, so
    # this denial keeps the error page and the theme, without the shell or
    # a link back into the admin. Policy denials still use {#render_forbidden}.
    # The template's only local is +error+. Navigation is a helper, so a host
    # override that declares strict locals for +error+ still renders.
    def render_authentication_denied
      @iron_admin_error_navigation = false

      respond_to do |format|
        format.html do
          render template: "iron_admin/shared/error",
                 layout: "iron_admin/minimal",
                 status: :forbidden,
                 locals: { error: :forbidden }
        end
        format.any { head(:forbidden) }
      end
    end

    # True on policy denials and 404s, which render inside the admin layout.
    # An authentication denial sets it false: the visitor is not signed in,
    # so the error page must not link into the admin or run a policy.
    # @return [Boolean]
    def iron_admin_error_navigation?
      @iron_admin_error_navigation != false
    end

    # A bare 403/404 makes the browser show its own error page, so HTML requests
    # get a page inside the admin layout. Other formats keep the bare status.
    def render_error_page(status)
      respond_to do |format|
        format.html { render template: "iron_admin/shared/error", status: status, locals: { error: status } }
        format.any { head(status) }
      end
    end

    def render_bad_request
      head(:bad_request)
    end

    def log_iron_admin_error(error)
      message = "[IronAdmin] #{error.class}: #{error.message}"
      backtrace = Rails.backtrace_cleaner.clean(Array(error.backtrace)).first(10)
      message = "#{message}\n#{backtrace.join("\n")}" if backtrace.any?
      Rails.logger.error(message)
    end
  end
end
