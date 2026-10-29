# frozen_string_literal: true

module IronAdmin
  module Layout
    # Navbar disclosure that switches between the registered themes. Each theme
    # is a submit button of a form posted to {IronAdmin::ThemesController}; the
    # +cp-disclosure+ Stimulus controller closes it on Escape and outside clicks.
    class ThemeSwitcherComponent < ViewComponent::Base
      # @param themes [Array<IronAdmin::Configuration::Theme>] Registered themes, default first
      # @param current_theme [IronAdmin::Configuration::Theme] Theme of the current request
      # @param current_user [Object, nil] Current user
      def initialize(themes:, current_theme:, current_user: nil)
        @themes = themes
        @current_theme = current_theme
        @current_user = current_user
      end

      # @return [Array<IronAdmin::Configuration::Theme>] Themes offered
      attr_reader :themes

      # @api private
      # @return [Boolean] Whether there is another theme to switch to
      def render?
        themes.size > 1
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme that styles the switcher
      def theme
        @current_theme
      end

      # @api private
      # @param option [IronAdmin::Configuration::Theme] One of {#themes}
      # @return [Boolean] Whether it is the theme of the current request
      def current?(option)
        option.name == @current_theme.name
      end

      # @api private
      # @return [String] Accessible name of the disclosure
      def summary_label
        I18n.t("iron_admin.theme_switcher.button_label", theme: @current_theme.label)
      end

      # @api private
      # @return [String] Accessible name of the list of themes
      def menu_label
        I18n.t("iron_admin.theme_switcher.menu_label")
      end

      # @api private
      # @return [String, nil] Path the switch returns to: the current path on a GET page; on a page
      #   answering a POST, which may have no GET route (an import preview), the same-site
      #   Referer's path, else nil (the admin root)
      def return_path
        return @return_path if defined?(@return_path)

        @return_path = request.get? || request.head? ? request.fullpath : referer_path
      end

      private

      def referer_path
        referer = URI.parse(request.referer.to_s)
        return unless referer.is_a?(URI::HTTP) && referer.host == request.host && referer.port == request.port

        referer.request_uri
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
