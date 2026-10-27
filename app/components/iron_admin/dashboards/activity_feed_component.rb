# frozen_string_literal: true

module IronAdmin
  module Dashboards
    # Renders an activity feed on the dashboard.
    class ActivityFeedComponent < ViewComponent::Base
      include Concerns::ThemedCard

      renders_many :items, "ItemComponent"

      # @return [String] Feed title
      attr_reader :title

      # @param title [String] Feed title (default: "Recent Activity")
      def initialize(title: "Recent Activity")
        @title = title
      end

      # @api private
      # @return [Boolean] Whether to render the component
      def render?
        items.any?
      end

      # Individual activity feed item component.
      # @api private
      class ItemComponent < ViewComponent::Base
        include Concerns::ThemedCard

        # @return [String] Icon name
        attr_reader :icon

        # @return [Symbol] Icon color, a key of the theme's badge palette
        attr_reader :icon_color

        # @return [String] Item description
        attr_reader :description

        # @return [Time, String] Item timestamp
        attr_reader :timestamp

        # @return [String, nil] Optional link URL
        attr_reader :href

        # @param description [String] Item description
        # @param timestamp [Time, String] Item timestamp
        # @param icon [String] Heroicon name (default: "circle-stack")
        # @param icon_color [Symbol] Icon color, a key of the theme's badge palette such as
        #   :green, :red, :yellow or :gray (default: :blue)
        # @param href [String, nil] Optional link URL
        def initialize(description:, timestamp:, icon: "circle-stack", icon_color: :blue, href: nil)
          @description = description
          @timestamp = timestamp
          @icon = icon
          @icon_color = icon_color.to_sym
          @href = href
        end

        # The icon tile is tinted like a badge of the same color; an unknown color is gray.
        #
        # @api private
        # @return [String] Icon tile colors from the theme's badge palette, and its radius
        def icon_classes
          palette = theme.badge_palette
          "#{palette.fetch(icon_color) { palette[:gray] }} #{theme.control_radius}"
        end

        # Only a row with an href is a link, so only it highlights on hover and shows a focus ring.
        #
        # @api private
        # @return [String] Classes of the row
        def row_classes
          return "flex items-center gap-3 px-5 py-3" unless href

          "flex items-center gap-3 px-5 py-3 transition-colors #{theme.item_hover} #{theme.focus_ring}"
        end

        # @api private
        # @return [String] Formatted timestamp string
        def formatted_timestamp
          if timestamp.respond_to?(:strftime)
            timestamp.strftime("%b %d, %H:%M")
          else
            timestamp
          end
        end
      end
    end
  end
end
