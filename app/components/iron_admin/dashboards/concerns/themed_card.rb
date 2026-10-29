# frozen_string_literal: true

module IronAdmin
  module Dashboards
    # Concerns shared by the dashboard components.
    module Concerns
      # Theme classes shared by the dashboard widgets, so every card, title,
      # label and icon tile on the dashboard reads the same theme properties.
      #
      # @api private
      module ThemedCard
        # @return [IronAdmin::Configuration::Theme] Theme of the current request
        def theme
          IronAdmin.current_theme
        end

        # @return [String] Card surface, border, radius and shadow
        def card_classes
          "#{theme.card_bg} #{theme.border_width} #{theme.card_border} #{theme.border_radius} #{theme.card_shadow}"
        end

        # @return [String] Widget title (h2): size, weight, color and font
        def title_classes
          "#{theme.card_title} #{theme.heading_font}"
        end

        # @return [String] Small label above a figure: size, weight, color and case
        def label_classes
          "#{theme.metric_label} #{theme.label_transform}"
        end

        # @return [String] Tile behind a widget icon: background, icon color and radius
        def icon_tile_classes
          "#{theme.metric_icon} #{theme.control_radius}"
        end
      end
    end
  end
end
