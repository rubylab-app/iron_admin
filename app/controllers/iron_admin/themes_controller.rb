# frozen_string_literal: true

module IronAdmin
  # Stores the theme picked in the theme switcher in the theme cookie, which the
  # default theme resolver reads. Only registered themes are stored.
  #
  # @see IronAdmin::Configuration#register_theme
  # @see IronAdmin::Configuration#theme_resolver
  class ThemesController < ApplicationController
    protect_from_forgery with: :exception

    # Characters that make a path unsafe to redirect to: browsers read a
    # backslash as a slash and drop tabs and newlines, so "/\evil.example"
    # becomes the protocol-relative "//evil.example".
    UNSAFE_PATH_CHARACTERS = /[\\[:cntrl:]]|[[:space:]]/

    # POST /theme
    #
    # @return [void]
    def update
      theme = IronAdmin.configuration.find_theme(theme_param)
      if theme
        cookies[Configuration::THEME_COOKIE] = {
          value: theme.name.to_s, expires: 1.year, httponly: true, same_site: :lax, secure: request.ssl?,
        }
      else
        flash[:alert] = I18n.t("iron_admin.theme_switcher.unknown")
      end
      redirect_to internal_return_path || root_path, status: :see_other
    end

    private

    def theme_param
      params[:theme] if params[:theme].is_a?(String)
    end

    # @return [String, nil] +return_to+ when it is a path on this host
    def internal_return_path
      path = params[:return_to]
      return unless path.is_a?(String) && path.start_with?("/") && !path.start_with?("//")
      return if path.match?(UNSAFE_PATH_CHARACTERS)

      uri = URI.parse(path)
      path if uri.scheme.nil? && uri.host.nil?
    rescue URI::InvalidURIError
      nil
    end
  end
end
