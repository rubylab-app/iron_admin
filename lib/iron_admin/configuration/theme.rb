# frozen_string_literal: true

require_relative "theme/neutral_defaults"

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

      # @return [String] Border and background color of checked checkboxes and radio buttons, and
      #   their focus ring. The check mark and the radio dot are always white (engine.css), in
      #   every color_scheme, so the checked background needs 3:1 contrast against white
      #   (WCAG 1.4.11)
      attr_accessor :checkbox_checked

      # @return [String] Border color of unchecked checkboxes and radio buttons. It is all that
      #   shows an unchecked control, so keep 3:1 against {#card_bg} (WCAG 1.4.11): Neutral's
      #   zinc-500 is 4.8:1 on white, while zinc-300 and zinc-400 are below 3:1
      attr_accessor :checkbox_border

      # @return [String] Radius of checkboxes (radio buttons are always round)
      attr_accessor :checkbox_radius

      # @return [String] Border color and focus state (ring width included) of inputs with
      #   validation errors, used instead of {#input_border} and {#input_focus}
      attr_accessor :input_error

      # @return [String] Color of input placeholders (with the +placeholder:+ variant)
      attr_accessor :placeholder_text

      # @return [String] Color of disabled pagination links and controls
      attr_accessor :disabled_text

      # @return [String] Radius of inputs, buttons, selects and dropdown items
      attr_accessor :control_radius

      # @return [String] Shadow of inputs, selects, textareas and buttons other than ghost ones (empty = none)
      attr_accessor :control_shadow

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

      # @return [String] Edge shadow of the sticky actions column of index tables (empty = none)
      attr_accessor :table_sticky_shadow

      # @return [String] Hover of table rows and of the dashboard's quick links and activity feed
      #   rows. These rows hold {#muted_text}, so keep AA contrast for it on this background
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

      # @return [String] Shadow of floating surfaces: dropdown menus, the filter panel, belongs-to
      #   autocomplete results, the theme switcher panel and modals (empty = none)
      attr_accessor :popover_shadow

      # @return [String, nil] Background of those floating surfaces, such as a raised tone in a dark
      #   theme (empty = {#card_bg}; read it through {#popover_background})
      attr_accessor :popover_bg

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

      # @return [String] Text transform and letter spacing of field labels: form and import form
      #   labels, action form labels and the field names of show pages; empty = as written
      attr_accessor :field_label_transform

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

      # @return [String] Border width of the outline of cards, panels, popovers, modals, alerts, inputs,
      #   checkboxes and pagination links. One-sided dividers (navbar bottom, panel and modal headers,
      #   form and bulk action footers, table rows, scope tabs) keep the width their template sets,
      #   and {#sidebar_border} and {#btn_secondary} carry their own width
      attr_accessor :border_width

      # @return [String] "light" or "dark": the CSS color scheme of browser UI and scrollbars
      #   (charts take {#chart_grid_color} and {#chart_text_color})
      attr_accessor :color_scheme

      # @return [String] Classes of this theme's swatch in the theme switcher
      attr_accessor :swatch

      # @return [String] Secondary backgrounds: readonly and disabled inputs, nested form rows,
      #   file previews, the empty state icon and audit change details
      attr_accessor :surface_muted

      # @return [String] Hover of dropdown and switcher items, search result rows and pagination
      #   links. Rows that hold {#muted_text} use {#table_row_hover}, a lighter background
      attr_accessor :item_hover

      # @return [String] Background of the listbox option that the arrow keys highlight
      #   (belongs-to autocomplete results)
      attr_accessor :item_active

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

      # @return [String] Background of floating surfaces: {#popover_bg}, or {#card_bg} while it is empty
      def popover_background
        popover_bg.presence || card_bg
      end

      # @return [Boolean] Whether {#color_scheme} is "dark"
      def dark?
        color_scheme.to_s == "dark"
      end

      # @return [String] Tailwind class of the +<html>+ element for {#color_scheme}
      def scheme_class
        SCHEME_CLASSES.fetch(dark? ? "dark" : "light")
      end
    end
  end
end
