# frozen_string_literal: true

module IronAdmin
  class Configuration
    # Theme configuration for customizing the admin panel appearance.
    #
    # All theme properties accept Tailwind CSS class strings. This allows
    # complete customization of colors, spacing, and visual styles.
    #
    # @example Customizing the theme
    #   IronAdmin.configure do |config|
    #     config.theme do |t|
    #       t.btn_primary = "bg-blue-600 text-white hover:bg-blue-700"
    #       t.sidebar_bg = "bg-slate-900"
    #       t.link = "text-blue-600 hover:text-blue-800"
    #     end
    #   end
    #
    # @see IronAdmin::Configuration#theme
    class Theme
      # @!group Button Styles

      # @return [String] Primary button classes (default: indigo)
      attr_accessor :btn_primary

      # @return [String] Secondary button classes (default: white with border)
      attr_accessor :btn_secondary

      # @return [String] Danger/destructive button classes (default: red)
      attr_accessor :btn_danger

      # @return [String] Ghost button classes (default: gray background)
      attr_accessor :btn_ghost

      # @!endgroup

      # @!group Link Styles

      # @return [String] Primary link classes
      attr_accessor :link

      # @return [String] Muted/secondary link classes
      attr_accessor :link_muted

      # @!endgroup

      # @!group Form Styles

      # @return [String] Focus ring classes for interactive elements
      attr_accessor :focus_ring

      # @return [String] Input border classes
      attr_accessor :input_border

      # @return [String] Input focus state classes
      attr_accessor :input_focus

      # @return [String] Checked checkbox classes
      attr_accessor :checkbox_checked

      # @!endgroup

      # @!group Tab/Scope Styles

      # @return [String] Active scope/tab classes
      attr_accessor :scope_active

      # @return [String] Inactive scope/tab classes
      attr_accessor :scope_inactive

      # @return [String] Badge counter classes
      attr_accessor :badge_count

      # @!endgroup

      # @!group Sidebar Styles

      # @return [String] Sidebar background classes
      attr_accessor :sidebar_bg

      # @return [String] Sidebar title text classes
      attr_accessor :sidebar_title

      # @return [String] Sidebar link classes
      attr_accessor :sidebar_link

      # @return [String] Sidebar link hover classes
      attr_accessor :sidebar_link_hover

      # @return [String] Classes of the sidebar link for the current page, used instead of
      #   {#sidebar_link} and {#sidebar_link_hover} (default: "bg-gray-800 text-white")
      attr_accessor :sidebar_link_active

      # @return [String] Sidebar group label classes
      attr_accessor :sidebar_group_label

      # @!endgroup

      # @!group Navbar Styles

      # @return [String] Navbar background classes
      attr_accessor :navbar_bg

      # @return [String] Navbar border classes
      attr_accessor :navbar_border

      # @return [String] Navbar search input background
      attr_accessor :navbar_search_bg

      # @return [String] Navbar search input focus background
      attr_accessor :navbar_search_focus_bg

      # @!endgroup

      # @!group Table Styles

      # @return [String] Table header background classes
      attr_accessor :table_header_bg

      # @return [String] Table row hover classes
      attr_accessor :table_row_hover

      # @return [String] Table border/divider classes
      attr_accessor :table_border

      # @!endgroup

      # @!group Card Styles

      # @return [String] Card background classes
      attr_accessor :card_bg

      # @return [String] Card border classes
      attr_accessor :card_border

      # @return [String] Card shadow classes
      attr_accessor :card_shadow

      # @!endgroup

      # @!group Typography

      # @return [String] Font family classes (empty = system default)
      attr_accessor :font_family

      # @return [String] Heading weight classes
      attr_accessor :heading_weight

      # @return [String] Body text color classes
      attr_accessor :body_text

      # @return [String] Muted text color classes
      attr_accessor :muted_text

      # @return [String] Label text color classes
      attr_accessor :label_text

      # @!endgroup

      # @!group Layout

      # @return [String] Main content area background classes
      attr_accessor :main_bg

      # @return [String] Border radius classes
      attr_accessor :border_radius

      # @!endgroup

      # @!group Chart Styles

      # @return [Array<String>] Default chart color palette (CSS color values: hex, rgb, rgba)
      attr_accessor :chart_colors

      # @return [String] Default chart border/line color (CSS color value)
      attr_accessor :chart_border_color

      # @!endgroup

      # Creates a new Theme with default values.
      def initialize
        # --- Buttons ---
        @btn_primary = "bg-indigo-600 text-white hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500/20 focus:ring-offset-1"
        @btn_secondary = "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 hover:border-gray-400"
        @btn_danger = "bg-red-600 text-white hover:bg-red-700"
        @btn_ghost = "bg-gray-100 text-gray-700 hover:bg-gray-200"

        # --- Links ---
        @link = "text-indigo-600 hover:text-indigo-900"
        @link_muted = "text-gray-500 hover:text-gray-700"

        # --- Focus ring ---
        @focus_ring = "focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20"

        # --- Inputs ---
        @input_border = "border-gray-300 hover:border-gray-400"
        @input_focus = "focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20"

        # --- Checkbox ---
        @checkbox_checked = "checked:border-indigo-600 checked:bg-indigo-600 focus:ring-2 focus:ring-indigo-500/20"

        # --- Scopes / Tabs ---
        @scope_active = "border-indigo-600 text-indigo-600"
        @scope_inactive = "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"

        # --- Badge counter ---
        @badge_count = "bg-indigo-600 text-white"

        init_sidebar_defaults

        # --- Navbar ---
        @navbar_bg = "bg-white"
        @navbar_border = "border-gray-200"
        @navbar_search_bg = "bg-gray-50"
        @navbar_search_focus_bg = "focus:bg-white"

        # --- Table ---
        @table_header_bg = "bg-gray-50"
        @table_row_hover = "hover:bg-gray-50"
        @table_border = "divide-gray-200"

        # --- Cards / Panels ---
        @card_bg = "bg-white"
        @card_border = "border-gray-200"
        @card_shadow = "shadow"

        # --- Typography ---
        @font_family = ""
        @heading_weight = "font-bold"
        @body_text = "text-gray-900"
        @muted_text = "text-gray-500"
        @label_text = "text-gray-700"

        # --- Layout ---
        @main_bg = "bg-gray-50"
        @border_radius = "rounded-lg"

        init_chart_defaults
      end

      private

      def init_sidebar_defaults
        @sidebar_bg = "bg-gray-900"
        @sidebar_title = "text-white"
        @sidebar_link = "text-gray-300"
        @sidebar_link_hover = "hover:bg-gray-800 hover:text-white"
        @sidebar_link_active = "bg-gray-800 text-white"
        @sidebar_group_label = "text-gray-400"
      end

      def init_chart_defaults
        @chart_colors = %w[
          rgba(99,102,241,0.8) rgba(59,130,246,0.8) rgba(16,185,129,0.8)
          rgba(245,158,11,0.8) rgba(239,68,68,0.8) rgba(139,92,246,0.8)
        ]
        @chart_border_color = "rgb(99, 102, 241)"
      end
    end
  end
end
