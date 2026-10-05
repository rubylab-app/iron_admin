# frozen_string_literal: true

module IronAdmin
  # Layout components for the admin panel structure.
  module Layout
    # Renders the main admin panel shell with sidebar and navbar.
    class ShellComponent < ViewComponent::Base
      renders_one :sidebar, SidebarComponent
      renders_one :navbar, NavbarComponent

      # @param current_user [Object, nil] Current user
      def initialize(current_user: nil)
        @current_user = current_user
      end

      # @api private
      # Sets up default sidebar and navbar if not provided.
      # @return [void]
      def before_render
        with_sidebar(current_user: @current_user) unless sidebar?
        with_navbar(current_user: @current_user) unless navbar?
      end
    end
  end
end
