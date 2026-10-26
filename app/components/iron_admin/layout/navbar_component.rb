# frozen_string_literal: true

module IronAdmin
  module Layout
    # Renders the top navigation bar.
    class NavbarComponent < ViewComponent::Base
      # @param current_user [Object, nil] Current user
      def initialize(current_user: nil)
        @current_user = current_user
      end

      # @api private
      # The query to keep in the search box. Only on the global search results
      # page: elsewhere +q+ belongs to the index page's own search box.
      # @return [String, nil]
      def search_query
        query = helpers.params[:q]
        query if query.is_a?(String) && helpers.controller.is_a?(IronAdmin::SearchController)
      end
    end
  end
end
