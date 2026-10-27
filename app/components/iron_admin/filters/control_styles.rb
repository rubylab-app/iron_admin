# frozen_string_literal: true

module IronAdmin
  module Filters
    # Classes of the filter controls, shared by the filter components, the index page's
    # built-in filter bar and the audit log filters. Colors, borders, radii and shadows
    # come from the theme.
    module ControlStyles
      module_function

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] Small label of a filter control
      def label(theme)
        "block text-xs font-medium #{theme.label_text} #{theme.label_transform}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] Text, number and date inputs
      def input(theme)
        "block w-full h-9 px-3 text-sm outline-none transition duration-150 ease-in-out #{field(theme)}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] Selects, with the engine's chevron (see engine.css)
      def select(theme)
        "block w-full h-9 pl-3 pr-9 text-sm appearance-none outline-none transition duration-150 ease-in-out " \
          "cp-select-chevron #{field(theme)}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The +<summary>+ that opens the filter panel, styled as a secondary button
      def trigger(theme)
        "inline-flex items-center gap-2 h-9 px-3.5 text-sm font-medium cursor-pointer select-none " \
          "transition duration-150 ease-in-out [&::-webkit-details-marker]:hidden " \
          "#{theme.control_radius} #{theme.btn_secondary} #{theme.focus_ring}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The floating filter panel
      def panel(theme)
        "absolute right-0 top-full z-20 mt-2 w-72 #{theme.card_bg} #{theme.border_width} " \
          "#{theme.card_border} #{theme.border_radius} #{theme.popover_shadow}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] Number of active filters next to the trigger's label
      def count(theme)
        "inline-flex items-center justify-center h-5 min-w-5 px-1.5 text-xs tabular-nums " \
          "#{theme.badge_shape} #{theme.badge_count}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] Row of the panel's Apply and Clear actions
      def footer(theme)
        "flex items-center gap-3 mt-4 pt-3 border-t #{theme.card_border}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The Apply button
      def apply_button(theme)
        "inline-flex items-center justify-center h-9 px-3.5 text-sm font-medium cursor-pointer " \
          "transition duration-150 ease-in-out #{theme.control_radius} #{theme.btn_primary}"
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] Border, surface, text and focus classes of inputs and selects
      def field(theme)
        "#{theme.border_width} #{theme.control_radius} #{theme.input_border} #{theme.card_bg} " \
          "#{theme.body_text} #{theme.placeholder_text} #{theme.input_focus}"
      end
    end
  end
end
