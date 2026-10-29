# frozen_string_literal: true

module IronAdmin
  module Ui
    # Renders a tooltip that appears on hover.
    #
    # @example Basic tooltip
    #   render IronAdmin::Ui::TooltipComponent.new(text: "More info") do
    #     heroicon("information-circle")
    #   end
    class TooltipComponent < ViewComponent::Base
      # @return [String] Tooltip text
      attr_reader :text

      # @return [Symbol] Position (:top, :bottom, :left, :right)
      attr_reader :position

      # Position class mappings.
      # @return [Hash{Symbol => String}]
      POSITIONS = {
        top: "bottom-full left-1/2 -translate-x-1/2 mb-2",
        bottom: "top-full left-1/2 -translate-x-1/2 mt-2",
        left: "right-full top-1/2 -translate-y-1/2 mr-2",
        right: "left-full top-1/2 -translate-y-1/2 ml-2",
      }.freeze

      # @param text [String] Tooltip text
      # @param position [Symbol] Position (default: :top)
      def initialize(text:, position: :top)
        @text = text
        @position = position.to_sym
      end

      # @api private
      # @return [String] CSS classes for tooltip position
      def position_classes
        POSITIONS[@position] || POSITIONS[:top]
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] CSS classes for tooltip container: shown on hover and
      #   while the trigger has keyboard focus, colored by the theme's +tooltip+
      def tooltip_classes
        "absolute #{position_classes} px-2 py-1 text-xs font-medium whitespace-nowrap pointer-events-none " \
          "opacity-0 invisible group-hover:opacity-100 group-hover:visible group-focus-within:opacity-100 " \
          "group-focus-within:visible transition-all duration-150 z-50 #{theme.tooltip} #{theme.control_radius}"
      end
    end
  end
end
