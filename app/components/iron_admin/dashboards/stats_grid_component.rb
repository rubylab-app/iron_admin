# frozen_string_literal: true

module IronAdmin
  module Dashboards
    # Renders a grid of statistics cards.
    class StatsGridComponent < ViewComponent::Base
      renders_many :stats, "StatComponent"

      # @return [Integer] Number of columns
      attr_reader :columns

      # @param columns [Integer] Grid columns (default: 4)
      def initialize(columns: 4)
        @columns = columns
      end

      # Four columns start at the xl breakpoint, as in the dashboard's metric grid:
      # from lg the static sidebar leaves the page about 700px, too narrow for four cards.
      #
      # @api private
      # @return [String] Tailwind grid column classes based on columns count
      def grid_classes
        case columns
        when 2 then "grid-cols-1 sm:grid-cols-2"
        when 3 then "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
        else "grid-cols-1 sm:grid-cols-2 xl:grid-cols-4"
        end
      end

      # Individual statistic card component.
      # @api private
      class StatComponent < ViewComponent::Base
        # @return [String] Stat label
        attr_reader :label

        # @return [Numeric, String] Stat value
        attr_reader :value

        # @return [String, nil] Change amount text
        attr_reader :change

        # @return [Symbol] Change type (:positive, :negative, :neutral)
        attr_reader :change_type

        # @return [String, nil] Optional icon name
        attr_reader :icon

        # @param label [String] Stat label
        # @param value [Numeric, String] Stat value
        # @param change [String, nil] Change amount text
        # @param change_type [Symbol] Change type (default: :neutral)
        # @param icon [String, nil] Optional Heroicon name
        def initialize(label:, value:, change: nil, change_type: :neutral, icon: nil)
          @label = label
          @value = value
          @change = change
          @change_type = change_type.to_sym
          @icon = icon
        end

        # @api private
        # @return [IronAdmin::Configuration::Theme] Theme configuration
        def theme
          IronAdmin.configuration.theme
        end

        # @api private
        # @return [String] CSS classes for change indicator color
        def change_classes
          case change_type
          when :positive then "text-green-600"
          when :negative then "text-red-600"
          else theme.muted_text
          end
        end

        # @api private
        # @return [String, nil] Heroicon name for change direction
        def change_icon
          case change_type
          when :positive then "arrow-trending-up"
          when :negative then "arrow-trending-down"
          end
        end
      end
    end
  end
end
