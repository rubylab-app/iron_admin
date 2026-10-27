# frozen_string_literal: true

module IronAdmin
  # Helper methods for accessing themed CSS classes.
  #
  # Provides convenience methods for generating Tailwind class strings
  # based on the current theme configuration.
  module ThemeHelper
    # Returns the theme of the current request (the default theme outside a request).
    # @return [IronAdmin::Configuration::Theme]
    def t
      IronAdmin.current_theme
    end

    # @return [Boolean] Whether the theme's font stylesheet is on Google Fonts, whose
    #   hosts the layout preconnects to
    def cp_google_fonts?
      URI.parse(t.font_stylesheet_url.to_s).host == "fonts.googleapis.com"
    rescue URI::InvalidURIError
      false
    end

    # @return [String] Primary button classes
    def cp_btn_primary
      Form::ControlClasses.button(t, :primary)
    end

    # @return [String] Classes of a form's submit button (the same as {#cp_btn_primary})
    def cp_btn_primary_lg
      cp_btn_primary
    end

    # @return [String] Secondary button classes
    def cp_btn_secondary
      Form::ControlClasses.button(t, :secondary)
    end

    # @return [String] Danger button classes
    def cp_btn_danger
      Form::ControlClasses.button(t, :danger)
    end

    # @return [String] Ghost button classes
    def cp_btn_ghost
      Form::ControlClasses.button(t, :ghost)
    end

    # @return [String] Link classes
    def cp_link
      t.link
    end

    # @return [String] Muted link classes
    def cp_link_muted
      t.link_muted
    end

    # @return [String] Focus ring classes
    def cp_focus
      t.input_focus
    end

    # @param error [Boolean] Whether the value failed validation
    # @param padding [String] Horizontal padding, such as "pl-7 pr-3" after a prefix
    # @return [String] Text input classes
    def cp_input_class(error: false, padding: Form::ControlClasses::INPUT_PADDING)
      Form::ControlClasses.input(t, error:, padding:)
    end

    # @param error [Boolean] Whether the value failed validation
    # @return [String] Select input classes, with the engine's chevron
    def cp_select_class(error: false)
      Form::ControlClasses.select(t, error:)
    end

    # @param error [Boolean] Whether the value failed validation
    # @return [String] Textarea classes
    def cp_textarea_class(error: false)
      Form::ControlClasses.textarea(t, error:)
    end

    # @return [String] Checkbox classes, with the engine's check mark
    def cp_checkbox_class
      Form::ControlClasses.checkbox(t)
    end

    # @return [String] Radio button classes, with the engine's dot
    def cp_radio_class
      Form::ControlClasses.radio(t)
    end

    # @return [String] Filter input classes
    def cp_filter_input_class
      Form::ControlClasses.input(t)
    end

    # @return [String] Classes of a search input with an icon on its left
    def cp_search_class
      Form::ControlClasses.input(t, padding: "pl-9 pr-3")
    end

    # @return [String] Navbar search input classes
    def cp_navbar_search_class
      "block w-full h-9 appearance-none pl-9 pr-3 text-sm outline-hidden transition duration-150 ease-in-out " \
        "#{t.control_radius} #{t.border_width} #{t.input_border} #{t.navbar_search_bg} #{t.body_text} " \
        "#{t.placeholder_text} #{t.input_focus} #{t.navbar_search_focus_bg}"
    end

    # @return [String] Active scope tab classes
    def cp_scope_active
      t.scope_active
    end

    # @return [String] Inactive scope tab classes
    def cp_scope_inactive
      t.scope_inactive
    end

    # @return [String] Badge count classes
    def cp_badge_count
      "inline-flex h-5 min-w-5 items-center justify-center px-1.5 text-xs tabular-nums #{t.badge_shape} #{t.badge_count}"
    end

    # @return [String] Filter apply button classes (a primary button)
    def cp_btn_filter_apply
      cp_btn_primary
    end

    # @return [String] Sidebar background classes
    def cp_sidebar_bg
      t.sidebar_bg
    end

    # @return [String] Sidebar title classes
    def cp_sidebar_title
      t.sidebar_title
    end

    # @return [String] Sidebar link classes
    def cp_sidebar_link
      "#{t.sidebar_link} #{t.sidebar_link_hover}"
    end

    # @return [String] Classes of the sidebar link for the current page
    def cp_sidebar_link_active
      t.sidebar_link_active
    end

    # @return [String] Sidebar group label classes
    def cp_sidebar_group_label
      t.sidebar_group_label
    end

    # @return [String] Heading classes: the heading weight and the heading font, or the body font without one
    def cp_heading
      "#{t.heading_weight} #{t.heading_font.presence || t.font_family}".strip
    end

    # @return [String] Card classes: background, border, radius and shadow
    def cp_card
      "#{t.card_bg} #{t.border_width} #{t.card_border} #{t.border_radius} #{t.card_shadow}"
    end

    # @return [String] Body text classes
    def cp_body_text
      t.body_text
    end

    # @return [String] Muted text classes
    def cp_muted_text
      t.muted_text
    end

    # @return [String] Label text classes
    def cp_label_text
      t.label_text
    end

    # @return [String] Table header background classes
    def cp_table_header_bg
      t.table_header_bg
    end

    # @return [String] Table row hover classes
    def cp_table_row_hover
      t.table_row_hover
    end

    # @return [String] Table border classes
    def cp_table_border
      t.table_border
    end

    # @param error [Boolean] Whether the upload failed validation
    # @return [String] File input classes
    def cp_file_input_class(error: false)
      Form::ControlClasses.file_input(t, error:)
    end
  end
end
