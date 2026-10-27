# frozen_string_literal: true

module IronAdmin
  # Ui components for common interface elements.
  module Ui
    # Renders a card container with optional header and footer.
    #
    # @example Basic card
    #   render IronAdmin::Ui::CardComponent.new do
    #     "Card content here"
    #   end
    #
    # @example Card with header and footer
    #   render IronAdmin::Ui::CardComponent.new do |card|
    #     card.with_header { "Title" }
    #     card.with_footer { "Footer" }
    #     "Content"
    #   end
    class CardComponent < ViewComponent::Base
      renders_one :header
      renders_one :footer

      # @return [Boolean] Whether to add padding to content
      attr_reader :padding

      # @return [Boolean] Whether to show shadow
      attr_reader :shadow

      # @param padding [Boolean] Add padding to content (default: true)
      # @param shadow [Boolean] Show card shadow (default: true)
      def initialize(padding: true, shadow: true)
        @padding = padding
        @shadow = shadow
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] CSS classes for card container
      def card_classes
        classes = ["overflow-hidden", theme.border_radius, theme.card_bg, "border", theme.card_border]
        classes << theme.card_shadow if shadow
        classes.join(" ")
      end

      # @api private
      # @return [String] CSS classes for card content area
      def content_classes
        padding ? "p-6" : ""
      end
    end
  end
end
