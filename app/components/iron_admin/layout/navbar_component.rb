# frozen_string_literal: true

module IronAdmin
  module Layout
    # Renders the top navigation bar: the global search box, the theme switcher
    # and the current user's name.
    class NavbarComponent < ViewComponent::Base
      # @param current_user [Object, nil] Current user
      def initialize(current_user: nil)
        @current_user = current_user
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # The +theme_switcher+ slot's component, only when two or more themes are registered.
      # @return [ViewComponent::Base, nil]
      def theme_switcher
        return @theme_switcher if defined?(@theme_switcher)

        @theme_switcher = build_theme_switcher
      end

      # @api private
      # The query to keep in the search box. Only on the global search results
      # page: elsewhere +q+ belongs to the index page's own search box.
      # @return [String, nil]
      def search_query
        query = helpers.params[:q]
        query if query.is_a?(String) && helpers.controller.is_a?(IronAdmin::SearchController)
      end

      private

      def build_theme_switcher
        themes = IronAdmin.configuration.themes.values
        return if themes.size < 2

        IronAdmin.configuration.components.build(:theme_switcher, themes: themes, current_theme: IronAdmin.current_theme,
                                                                  current_user: @current_user)
      end
    end
  end
end
