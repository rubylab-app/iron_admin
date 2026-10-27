# frozen_string_literal: true

module IronAdmin
  module Layout
    # Renders the sidebar navigation menu.
    #
    # The current page's link gets +aria-current="page"+ and the theme's
    # +sidebar_link_active+ classes. See the theming guide for which pages
    # make each link current.
    class SidebarComponent < ViewComponent::Base
      include IronAdmin::ThemeHelper

      # Layout classes of every sidebar link, current or not. Its radius, focus
      # outline and colors come from the theme.
      LINK_CLASSES = "relative flex items-center gap-2.5 px-2.5 py-1.5 text-sm font-medium"

      # Classes of the icon of a sidebar link.
      ICON_CLASSES = "h-4 w-4 shrink-0"

      # @param current_user [Object, nil]
      def initialize(current_user: nil)
        @current_user = current_user
      end

      # Returns resources grouped by menu group.
      # Resources the current user cannot read are omitted.
      # @return [Hash{String => Array<Class>}]
      def grouped_resources
        IronAdmin::ResourceRegistry.grouped.each_with_object({}) do |(group, resources), visible|
          readable = resources.select { |resource| resource.crud_allowed?(:read, @current_user) }
          visible[group] = readable if readable.any?
        end
      end

      # Returns tools grouped by menu group.
      # @return [Hash{String => Array<Class>}]
      def grouped_tools
        IronAdmin::ToolRegistry.grouped
      end

      # Returns custom menu items (e.g. from plugins) grouped by menu group.
      # Items are ordered by priority; ties keep their registration order.
      # @return [Hash{String => Array<IronAdmin::MenuItem>}]
      def grouped_menu_items
        IronAdmin::MenuRegistry.all
          .sort_by.with_index { |item, index| [item.priority, index] }
          .group_by(&:group)
      end

      # @api private
      # @param active [Boolean] Whether the link is for the current page
      # @param extra [String] More classes for the link
      # @return [Hash] +link_to+ options: the link classes, plus +aria-current="page"+ when +active+
      def link_options(active, extra = nil)
        classes = [LINK_CLASSES, theme.control_radius, theme.focus_ring, active ? cp_sidebar_link_active : cp_sidebar_link, extra]
        { class: classes.compact_blank.join(" "), aria: { current: ("page" if active) } }
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] Classes of the group labels: the theme's label case and color
      def group_label_classes
        "#{theme.label_transform} #{theme.sidebar_group_label}".strip
      end

      # @api private
      # @return [Boolean] Whether the current page is the dashboard
      def dashboard_active?
        path_parameter(:controller) == "iron_admin/dashboard"
      end

      # @api private
      # @param resource [Class<IronAdmin::Resource>]
      # @return [Boolean] Whether the current page belongs to +resource+
      def resource_active?(resource)
        path_parameter(:resource_name) == resource.resource_name.to_s
      end

      # @api private
      # @param tool [Class<IronAdmin::Tool>]
      # @return [Boolean] Whether the current page belongs to +tool+
      def tool_active?(tool)
        path_parameter(:tool_name) == tool.tool_name.to_s
      end

      # @api private
      # Query strings, fragments and a trailing slash are ignored.
      #
      # @param item [IronAdmin::MenuItem]
      # @return [Boolean] Whether the request's path (or URL, for an absolute item URL) is the item's
      def menu_item_active?(item)
        item_url = item.path.sub(/[?#].*\z/, "").chomp("/")
        request = helpers.request
        current_url = item_url.match?(%r{\A[a-z][a-z\d+.-]*://}i) ? "#{request.base_url}#{request.path}" : request.path
        item_url == current_url.chomp("/")
      end

      # @api private
      # @return [String] Configured admin panel title
      def title
        IronAdmin.configuration.title
      end

      # @api private
      # @return [String, nil] Configured logo URL or path
      def logo
        IronAdmin.configuration.logo
      end

      private

      # From the route, not the query string, so +?resource_name=+ cannot mark a link current.
      def path_parameter(name)
        helpers.request.path_parameters[name]&.to_s
      end
    end
  end
end
