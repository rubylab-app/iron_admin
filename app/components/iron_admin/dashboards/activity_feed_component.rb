# frozen_string_literal: true

module IronAdmin
  module Dashboards
    # Renders an activity feed on the dashboard.
    class ActivityFeedComponent < ViewComponent::Base
      renders_many :items, "ItemComponent"

      # @return [String] Feed title
      attr_reader :title

      # @param title [String] Feed title (default: "Recent Activity")
      def initialize(title: "Recent Activity")
        @title = title
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [Boolean] Whether to render the component
      def render?
        items.any?
      end

      # Individual activity feed item component.
      # @api private
      class ItemComponent < ViewComponent::Base
        # @return [String] Icon name
        attr_reader :icon

        # @return [Symbol] Icon color
        attr_reader :icon_color

        # @return [String] Item description
        attr_reader :description

        # @return [Time, String] Item timestamp
        attr_reader :timestamp

        # @return [String, nil] Optional link URL
        attr_reader :href

        # Color classes for icon backgrounds.
        # @api private
        COLORS = {
          green: "bg-green-100 text-green-600",
          red: "bg-red-100 text-red-600",
          blue: "bg-blue-100 text-blue-600",
          yellow: "bg-yellow-100 text-yellow-600",
          gray: "bg-gray-100 text-gray-600",
        }.freeze

        # @param description [String] Item description
        # @param timestamp [Time, String] Item timestamp
        # @param icon [String] Heroicon name (default: "circle-stack")
        # @param icon_color [Symbol] Icon color (default: :blue)
        # @param href [String, nil] Optional link URL
        def initialize(description:, timestamp:, icon: "circle-stack", icon_color: :blue, href: nil)
          @description = description
          @timestamp = timestamp
          @icon = icon
          @icon_color = icon_color.to_sym
          @href = href
        end

        # @api private
        # @return [IronAdmin::Configuration::Theme] Theme of the current request
        def theme
          IronAdmin.current_theme
        end

        # @api private
        # @return [String] CSS classes for icon background color
        def icon_classes
          COLORS[@icon_color] || COLORS[:gray]
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
