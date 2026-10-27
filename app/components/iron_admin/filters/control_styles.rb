# frozen_string_literal: true

module IronAdmin
  module Filters
    # Classes of the filter controls, shared by the filter components, the index page's
    # built-in filter bar and the audit log filters. Inputs, selects and buttons are the
    # form controls of {IronAdmin::Form::ControlClasses}; colors, borders, radii and
    # shadows come from the theme.
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
        Form::ControlClasses.input(theme)
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] Selects, with the engine's chevron (see engine.css)
      def select(theme)
        Form::ControlClasses.select(theme)
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The search input, with room for the magnifying glass on its left
      def search_input(theme)
        Form::ControlClasses.input(theme, padding: "pl-9 pr-3")
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] The +<summary>+ that opens the filter panel, styled as a secondary button
      def trigger(theme)
        "#{Form::ControlClasses.button(theme, :secondary)} select-none [&::-webkit-details-marker]:hidden"
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
        Form::ControlClasses.button(theme, :primary)
      end
    end
  end
end
