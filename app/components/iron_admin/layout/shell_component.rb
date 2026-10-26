# frozen_string_literal: true

module IronAdmin
  # Layout components for the admin panel structure.
  module Layout
    # Renders the main admin panel shell with sidebar and navbar.
    #
    # The sidebar, navbar and flash messages are the ones set in
    # +config.components+ (or a plugin), falling back to {SidebarComponent},
    # {NavbarComponent} and {FlashComponent}. Flash messages render above the
    # page content.
    class ShellComponent < ViewComponent::Base
      renders_one :sidebar, ->(**arguments) { IronAdmin.configuration.components.build(:sidebar, **arguments) }
      renders_one :navbar, ->(**arguments) { IronAdmin.configuration.components.build(:navbar, **arguments) }

      # @param current_user [Object, nil] Current user
      def initialize(current_user: nil)
        @current_user = current_user
      end

      # @api private
      # @return [ViewComponent::Base] The +flash+ slot's component, given the request's flash
      def flash_messages
        IronAdmin.configuration.components.build(:flash, flash: helpers.flash, current_user: @current_user)
      end

      # @api private
      # Sets up default sidebar and navbar if not provided.
      # @return [void]
      def before_render
        with_sidebar(current_user: @current_user) unless sidebar?
        with_navbar(current_user: @current_user, title: IronAdmin.configuration.title) unless navbar?
      end
    end
  end
end
