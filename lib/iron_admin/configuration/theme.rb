# frozen_string_literal: true

module IronAdmin
  class Configuration
    # A named look of the admin panel. A new Theme holds the values of the built-in
    # Neutral look. Properties hold Tailwind classes, except the chart colors, the
    # font stylesheet URL and the color scheme.
    #
    # @see IronAdmin::Configuration#theme
    # @see IronAdmin::Configuration#register_theme
    class Theme
      # Tailwind class that sets the CSS +color-scheme+ of each {#color_scheme}.
      # @return [Hash{String => String}]
      SCHEME_CLASSES = { "light" => "scheme-light", "dark" => "scheme-dark" }.freeze

      # @return [Symbol] Name the theme is registered under (and the value of the theme cookie)
      attr_reader :name

      # @return [String] Human name shown in the theme switcher
      attr_reader :label

      # @!group Button Styles

      # @return [String] Primary button colors and focus outline
      attr_accessor :btn_primary

      # @return [String] Secondary button colors and border
      attr_accessor :btn_secondary

      # @return [String] Danger/destructive button colors
      attr_accessor :btn_danger

      # @return [String] Ghost button colors
      attr_accessor :btn_ghost

      # @!endgroup

      # @!group Link Styles

      # @return [String] Primary link classes
      attr_accessor :link

      # @return [String] Muted/secondary link classes
      attr_accessor :link_muted

      # @!endgroup

      # @!group Form Styles

      # @return [String] Focus indicator of interactive elements other than inputs
      attr_accessor :focus_ring

      # @return [String] Input border color classes
      attr_accessor :input_border

      # @return [String] Input focus state classes
      attr_accessor :input_focus

      # @return [String] Checked checkbox classes
      attr_accessor :checkbox_checked

      # @return [String] Border color and focus ring of inputs with validation errors
      attr_accessor :input_error

      # @return [String] Color of input placeholders (with the +placeholder:+ variant)
      attr_accessor :placeholder_text

      # @return [String] Color of disabled pagination links and controls
      attr_accessor :disabled_text

      # @return [String] Radius of inputs, buttons, selects and dropdown items
      attr_accessor :control_radius

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

      # @return [String] Sidebar edge (border side and color) on large screens
      attr_accessor :sidebar_border

      # @return [String] Sidebar title text classes
      attr_accessor :sidebar_title

      # @return [String] Sidebar link classes
      attr_accessor :sidebar_link

      # @return [String] Sidebar link hover classes
      attr_accessor :sidebar_link_hover

      # @return [String] Classes of the sidebar link for the current page, used instead of
      #   {#sidebar_link} and {#sidebar_link_hover}. The link is +relative+, so
      #   +before:+ utilities can draw an accent bar.
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

      # @return [String] Color of the user name and other navbar text
      attr_accessor :navbar_text

      # @return [String] Keyboard hint (such as the search shortcut): border, background and text color
      attr_accessor :kbd

      # @return [String] Skip link once it receives focus (with the +focus:+ variant)
      attr_accessor :skip_link

      # @!endgroup

      # @!group Table Styles

      # @return [String] Table header background classes
      attr_accessor :table_header_bg

      # @return [String] Table header cells: size, weight and color
      attr_accessor :table_header_text

      # @return [String] Padding (density) of table body and header cells
      attr_accessor :table_cell_padding

      # @return [String] Extra classes of the table container (empty = none)
      attr_accessor :table_frame

      # @return [String] Table row hover classes
      attr_accessor :table_row_hover

      # @return [String] Table border/divider classes
      attr_accessor :table_border

      # @!endgroup

      # @!group Card Styles

      # @return [String] Card background classes
      attr_accessor :card_bg

      # @return [String] Card border color classes
      attr_accessor :card_border

      # @return [String] Card shadow classes
      attr_accessor :card_shadow

      # @return [String] Card and section titles (h2): size, weight and color
      attr_accessor :card_title

      # @!endgroup

      # @!group Typography

      # @return [String] Font family classes of the page (empty = system default)
      attr_accessor :font_family

      # @return [String, nil] Stylesheet the layout links for the theme's fonts (nil = none)
      attr_accessor :font_stylesheet_url

      # @return [String] Extra font family classes of page and card titles (empty = {#font_family})
      attr_accessor :heading_font

      # @return [String] Heading weight classes
      attr_accessor :heading_weight

      # @return [String] Page title (h1): size, weight, tracking and color
      attr_accessor :page_title

      # @return [String] Text transform and letter spacing of small labels (sidebar groups,
      #   table headers, metric labels); empty = as written
      attr_accessor :label_transform

      # @return [String] Body text color classes
      attr_accessor :body_text

      # @return [String] Muted text color classes
      attr_accessor :muted_text

      # @return [String] Label text color classes
      attr_accessor :label_text

      # @return [String] Color of validation messages, required marks and negative deltas
      attr_accessor :error_text

      # @return [String] Color of positive deltas and true booleans
      attr_accessor :success_text

      # @!endgroup

      # @!group Layout

      # @return [String] Main content area background classes
      attr_accessor :main_bg

      # @return [String] Border radius of cards and panels (inputs and buttons use {#control_radius})
      attr_accessor :border_radius

      # @return [String] Border width used with every border color property
      attr_accessor :border_width

      # @return [String] "light" or "dark": the CSS color scheme of browser UI, scrollbars and charts
      attr_accessor :color_scheme

      # @return [String] Classes of this theme's swatch in the theme switcher
      attr_accessor :swatch

      # @return [String] Secondary backgrounds (readonly inputs, nested rows, empty state icon, file button)
      attr_accessor :surface_muted

      # @return [String] Hover of menu items, list rows and pagination links
      attr_accessor :item_hover

      # @return [String] Color of decorative icons
      attr_accessor :icon_muted

      # @return [String] Backdrop of modals and drawers
      attr_accessor :overlay_bg

      # @!endgroup

      # @!group Feedback Styles

      # @return [Hash{Symbol => String}] Alert, flash and warning panel classes (background, border
      #   color, text color) by type: +:success+, +:error+, +:warning+, +:info+
      attr_accessor :alert_palette

      # @return [Hash{Symbol => String}] Badge classes by color name (+:green+, +:red+, +:yellow+,
      #   +:blue+, +:indigo+, +:purple+, +:pink+, +:orange+, +:teal+, +:gray+)
      attr_accessor :badge_palette

      # @return [Hash{Symbol => String}] Badge dot classes by color name ({#badge_palette} keys);
      #   an empty Hash renders badges without a dot
      attr_accessor :badge_dot_palette

      # @return [String] Radius and font weight of badges
      attr_accessor :badge_shape

      # @return [String] Tags and has-many chips
      attr_accessor :chip

      # @return [String] Color of destructive dropdown items, with their hover
      attr_accessor :danger_item

      # @return [String] Tooltip background and text color
      attr_accessor :tooltip

      # @return [String] JSON/code display background and text color
      attr_accessor :code_block

      # @return [String] Progress bar track
      attr_accessor :progress_track

      # @return [String] Current page of the pagination
      attr_accessor :pagination_active

      # @!endgroup

      # @!group Dashboard Styles

      # @return [String] Dashboard metric label: size, weight and color
      attr_accessor :metric_label

      # @return [String] Dashboard metric figure: size, weight, tracking and color
      attr_accessor :metric_value

      # @return [String] Dashboard metric icon tile: background and icon color
      attr_accessor :metric_icon

      # @!endgroup

      # @!group Chart Styles

      # @return [Array<String>] Default chart color palette (CSS color values: hex, rgb, rgba)
      attr_accessor :chart_colors

      # @return [String] Default chart border/line color (CSS color value)
      attr_accessor :chart_border_color

      # @return [String] Chart grid lines (CSS color value)
      attr_accessor :chart_grid_color

      # @return [String] Chart ticks and legend (CSS color value)
      attr_accessor :chart_text_color

      # @!endgroup

      # --- data additions ---

      # @!group Data Styles

      # @return [String] Shadow of floating panels, such as the filter panel of the index page
      def popover_shadow
        defined?(@popover_shadow) ? @popover_shadow : "shadow-lg"
      end

      # @return [String] Edge shadow of the sticky actions column of index tables
      def table_sticky_shadow
        defined?(@table_sticky_shadow) ? @table_sticky_shadow : "shadow-[-4px_0_6px_-4px_rgba(0,0,0,0.08)]"
      end

      attr_writer :popover_shadow, :table_sticky_shadow

      # @!endgroup

      # --- end of data additions ---

      # Creates a Theme with the values of the Neutral look.
      #
      # @param name [Symbol, String] Name the theme is registered under
      # @param label [String, nil] Name shown in the theme switcher (default: the titleized name)
      def initialize(name: :neutral, label: nil)
        @name = name.to_sym
        @label = (label || @name.to_s.titleize).to_s
        init_control_defaults
        init_form_defaults
        init_navigation_defaults
        init_surface_defaults
        init_typography_defaults
        init_feedback_defaults
        init_palette_defaults
        init_chart_defaults
      end

      # Copies Array and Hash values (chart colors, palettes) too, so a copy never shares them.
      #
      # @param source [Theme] The theme being copied
      # @return [void]
      def initialize_copy(source)
        super
        instance_variables.each do |variable|
          value = instance_variable_get(variable)
          instance_variable_set(variable, value.deep_dup) if value.is_a?(Array) || value.is_a?(Hash)
        end
      end

      # @return [Boolean] Whether {#color_scheme} is "dark"
      def dark?
        color_scheme.to_s == "dark"
      end

      # @return [String] Tailwind class of the +<html>+ element for {#color_scheme}
      def scheme_class
        SCHEME_CLASSES.fetch(dark? ? "dark" : "light")
      end

      private

      def init_control_defaults
        @btn_primary = "bg-zinc-900 text-white hover:bg-zinc-700 " \
                       "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500"
        @btn_secondary = "bg-white text-zinc-900 border border-zinc-200 hover:bg-zinc-50 hover:border-zinc-300"
        @btn_danger = "bg-red-600 text-white hover:bg-red-700"
        @btn_ghost = "bg-transparent text-zinc-700 hover:bg-zinc-100 hover:text-zinc-900"
        @link = "text-indigo-600 hover:text-indigo-500"
        @link_muted = "text-zinc-500 hover:text-zinc-900"
        @focus_ring = "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500"
        @control_radius = "rounded-md"
      end

      def init_form_defaults
        @input_border = "border-zinc-200 hover:border-zinc-300"
        @input_focus = "focus:border-indigo-500 focus:ring-3 focus:ring-indigo-500/15"
        @checkbox_checked = "checked:border-indigo-600 checked:bg-indigo-600 focus:ring-3 focus:ring-indigo-500/15"
        @input_error = "border-red-400 focus:border-red-500 focus:ring-red-500/20"
        @placeholder_text = "placeholder:text-zinc-500"
        @disabled_text = "text-zinc-300"
      end

      def init_navigation_defaults
        @scope_active = "border-zinc-900 text-zinc-900"
        @scope_inactive = "border-transparent text-zinc-500 hover:text-zinc-900 hover:border-zinc-300"
        @badge_count = "bg-zinc-100 text-zinc-700"
        @sidebar_bg = "bg-zinc-50"
        @sidebar_border = "lg:border-r border-zinc-200"
        @sidebar_title = "text-zinc-900"
        @sidebar_link = "text-zinc-600"
        @sidebar_link_hover = "hover:bg-zinc-200/60 hover:text-zinc-900"
        @sidebar_link_active = "bg-white text-zinc-900 shadow-xs ring-1 ring-zinc-200 before:absolute before:left-0 " \
                               "before:inset-y-2 before:w-0.5 before:rounded-full before:bg-indigo-500"
        @sidebar_group_label = "text-zinc-500"
        @navbar_bg = "bg-white"
        @navbar_border = "border-zinc-200"
        @navbar_search_bg = "bg-zinc-50"
        @navbar_search_focus_bg = "focus:bg-white"
        @navbar_text = "text-zinc-600"
        @kbd = "border-zinc-200 bg-white text-zinc-500"
        @skip_link = "focus:bg-white focus:text-zinc-900 focus:ring-2 focus:ring-indigo-500"
      end

      def init_surface_defaults
        @table_header_bg = "bg-zinc-50"
        @table_header_text = "text-xs font-medium text-zinc-500"
        @table_cell_padding = "px-4 py-2.5"
        @table_frame = ""
        @table_row_hover = "hover:bg-zinc-50"
        @table_border = "divide-zinc-200"
        @card_bg = "bg-white"
        @card_border = "border-zinc-200"
        @card_shadow = "shadow-xs"
        @card_title = "text-sm font-semibold text-zinc-900"
        @main_bg = "bg-zinc-50"
        @border_radius = "rounded-lg"
        @border_width = "border"
        @color_scheme = "light"
        @swatch = "bg-white ring-1 ring-inset ring-zinc-300"
        @surface_muted = "bg-zinc-50"
        @item_hover = "hover:bg-zinc-100"
        @icon_muted = "text-zinc-400"
        @overlay_bg = "bg-zinc-900/40"
      end

      def init_typography_defaults
        @font_family = "font-[family-name:Inter,ui-sans-serif,system-ui,sans-serif]"
        @font_stylesheet_url = "https://fonts.googleapis.com/css2?family=Inter:wght@400..700&display=swap"
        @heading_font = ""
        @heading_weight = "font-semibold"
        @page_title = "text-xl font-semibold tracking-tight text-zinc-900"
        @label_transform = ""
        @body_text = "text-zinc-900"
        @muted_text = "text-zinc-500"
        @label_text = "text-zinc-700"
        @error_text = "text-red-600"
        @success_text = "text-emerald-700"
      end

      def init_feedback_defaults
        @badge_shape = "rounded-md font-medium"
        @chip = "bg-zinc-100 text-zinc-700 ring-1 ring-inset ring-zinc-200"
        @danger_item = "text-red-600 hover:bg-red-50 hover:text-red-700"
        @tooltip = "bg-zinc-900 text-white"
        @code_block = "bg-zinc-950 text-zinc-100"
        @progress_track = "bg-zinc-200"
        @pagination_active = "bg-zinc-900 text-white border-zinc-900"
        @metric_label = "text-xs font-medium text-zinc-500"
        @metric_value = "text-2xl font-semibold tracking-tight tabular-nums text-zinc-900"
        @metric_icon = "bg-zinc-100 text-zinc-500"
      end

      def init_palette_defaults
        @alert_palette = {
          success: "bg-emerald-50 border-emerald-200 text-emerald-800",
          error: "bg-red-50 border-red-200 text-red-800",
          warning: "bg-amber-50 border-amber-200 text-amber-800",
          info: "bg-blue-50 border-blue-200 text-blue-800",
        }
        @badge_palette = {
          green: "bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-600/20",
          red: "bg-red-50 text-red-700 ring-1 ring-inset ring-red-600/10",
          yellow: "bg-amber-50 text-amber-800 ring-1 ring-inset ring-amber-600/20",
          blue: "bg-blue-50 text-blue-700 ring-1 ring-inset ring-blue-700/10",
          indigo: "bg-indigo-50 text-indigo-700 ring-1 ring-inset ring-indigo-700/10",
          purple: "bg-purple-50 text-purple-700 ring-1 ring-inset ring-purple-700/10",
          pink: "bg-pink-50 text-pink-700 ring-1 ring-inset ring-pink-700/10",
          orange: "bg-orange-50 text-orange-800 ring-1 ring-inset ring-orange-600/20",
          teal: "bg-teal-50 text-teal-700 ring-1 ring-inset ring-teal-600/20",
          gray: "bg-zinc-50 text-zinc-600 ring-1 ring-inset ring-zinc-500/10",
        }
        @badge_dot_palette = {
          green: "bg-emerald-500",
          red: "bg-red-500",
          yellow: "bg-amber-500",
          blue: "bg-blue-500",
          indigo: "bg-indigo-500",
          purple: "bg-purple-500",
          pink: "bg-pink-500",
          orange: "bg-orange-500",
          teal: "bg-teal-500",
          gray: "bg-zinc-400",
        }
      end

      def init_chart_defaults
        @chart_colors = %w[
          rgba(99,102,241,0.85) rgba(14,165,233,0.85) rgba(16,185,129,0.85)
          rgba(245,158,11,0.85) rgba(244,63,94,0.85) rgba(139,92,246,0.85)
        ]
        @chart_border_color = "rgb(99, 102, 241)"
        @chart_grid_color = "rgba(228, 228, 231, 1)"
        @chart_text_color = "rgb(113, 113, 122)"
      end
    end
  end
end
