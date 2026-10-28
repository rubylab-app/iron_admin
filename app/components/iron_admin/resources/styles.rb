# frozen_string_literal: true

module IronAdmin
  module Resources
    # Classes of the page titles, panels and tables of the resource, search and audit
    # pages, built from theme properties.
    module Styles
      # Field types whose table cells line up their digits.
      # @return [Array<Symbol>]
      NUMERIC_TYPES = %i[number currency].freeze

      # A label and value row of a show page panel. The label sits at the top of the row, beside
      # the first line of a long value.
      # @return [String]
      DETAIL_ROW = "flex flex-col gap-1 px-4 py-3 sm:flex-row sm:items-start"

      # The box a table scrolls sideways in, inside its {.table_panel}: rounded like the panel, with
      # the engine's fade at the edge it can still scroll toward. The fade masks this box, so the
      # panel's border, on the box around it, keeps its color.
      # @return [String]
      SCROLL_FRAME = "overflow-x-auto rounded-[inherit] cp-scroll-fade"

      module_function

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The page's h1
      def page_title(theme)
        "#{theme.page_title} #{theme.heading_font}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] A white card holding a table, a list or detail rows
      def panel(theme)
        "#{theme.card_bg} #{theme.border_width} #{theme.card_border} #{theme.border_radius} #{theme.card_shadow}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The title row of a panel
      def panel_header(theme)
        "flex items-center justify-between gap-3 px-4 py-3 border-b #{theme.card_border}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The h2 of a panel
      def panel_title(theme)
        "#{theme.card_title} #{theme.heading_font}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The panel a table scrolls in
      def table_frame(theme)
        "overflow-x-auto #{panel(theme)} #{theme.table_frame}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The panel of a table that scrolls in a {SCROLL_FRAME} inside it
      def table_panel(theme)
        "#{panel(theme)} #{theme.table_frame}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The table, its head divided from its body
      def table(theme)
        "min-w-full divide-y #{theme.table_head_divider}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] A table body, list or detail list whose rows are divided
      def divided(theme)
        "divide-y #{theme.table_border}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] A link that fills a row of a divided panel; the first and last
      #   take the panel's radius, so their hover background keeps its corners
      def list_row(theme)
        "block px-4 py-3 text-sm first:rounded-t-[inherit] last:rounded-b-[inherit] " \
          "#{theme.body_text} #{theme.item_hover} #{theme.focus_ring}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] A header cell
      def header_cell(theme)
        "text-left whitespace-nowrap #{theme.table_cell_padding} #{theme.table_header_text} #{theme.label_transform}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @param field [IronAdmin::Field, nil] The cell's field; numeric ones line up their digits
      # @return [String] A body cell
      def cell(theme, field = nil)
        classes = "whitespace-nowrap text-sm #{theme.table_cell_padding} #{theme.body_text}"
        NUMERIC_TYPES.include?(field&.type) ? "#{classes} tabular-nums" : classes
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] A body cell of secondary information
      def muted_cell(theme)
        "whitespace-nowrap text-sm #{theme.table_cell_padding} #{theme.muted_text}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The header cell of the sticky actions column
      def sticky_header_cell(theme)
        "sticky right-0 z-10 #{theme.table_header_bg} #{theme.table_sticky_shadow}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] A body cell of the sticky actions column
      def sticky_cell(theme)
        "sticky right-0 z-10 #{theme.card_bg} #{theme.table_sticky_row_hover} #{theme.table_sticky_shadow}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] A secondary button, such as a bulk or member action, like the form buttons
      def secondary_button(theme)
        Form::ControlClasses.button(theme, :secondary)
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] A ghost button, such as the audit log's Clear link, like the form buttons
      def ghost_button(theme)
        Form::ControlClasses.button(theme, :ghost)
      end
    end
  end
end
