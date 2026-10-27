# frozen_string_literal: true

module IronAdmin
  module Ui
    # A status badge in the theme's +badge_palette+ colors, with a +badge_dot_palette+ dot.
    #
    # @example Basic usage
    #   render IronAdmin::Ui::BadgeComponent.new(text: "Active", color: :green)
    #
    # @example With size
    #   render IronAdmin::Ui::BadgeComponent.new(text: "New", color: :blue, size: :sm)
    class BadgeComponent < ViewComponent::Base
      # @return [String] The text displayed in the badge
      attr_reader :text

      # @return [Symbol] The color theme (:green, :red, :yellow, :blue, etc.)
      attr_reader :color

      # @return [Symbol] The size (:sm, :md, :lg)
      attr_reader :size

      # Badge classes of the built-in Neutral theme by color name, kept for code that
      # reads them. Badges use the current theme's +badge_palette+.
      # @return [Hash{Symbol => String}]
      COLORS = IronAdmin::Configuration::Theme.new.badge_palette.freeze

      # Available sizes mapped to Tailwind classes.
      # @return [Hash{Symbol => String}]
      SIZES = {
        sm: "px-1.5 py-0.5 text-xs",
        md: "px-2 py-0.5 text-xs",
        lg: "px-2.5 py-1 text-sm",
      }.freeze

      # @param text [String] The badge text
      # @param color [Symbol] Color theme (default: :gray)
      # @param size [Symbol] Size variant (default: :md)
      def initialize(text:, color: :gray, size: :md)
        @text = text
        @color = color.to_sym
        @size = size.to_sym
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] The +config.badge_colors+ classes of the color, else the theme's
      #   palette classes of the color (gray for an unknown color)
      def color_classes
        configured_classes || theme.badge_palette.fetch(palette_color, "")
      end

      # @api private
      # @return [String, nil] Dot classes; nil without a theme dot or with +config.badge_colors+ classes
      def dot_classes
        theme.badge_dot_palette[palette_color] unless configured_classes
      end

      # @api private
      # @return [String] CSS size classes for badge
      def size_classes
        SIZES[@size] || SIZES[:md]
      end

      # Renders the badge span.
      # @return [String] HTML content
      def call
        tag.span(class: "inline-flex items-center gap-1.5 #{size_classes} #{theme.badge_shape} #{color_classes}") do
          safe_join([dot, text].compact)
        end
      end

      private

      def configured_classes
        IronAdmin.configuration.badge_colors[@color]
      end

      def palette_color
        theme.badge_palette.key?(@color) ? @color : :gray
      end

      def dot
        classes = dot_classes
        tag.span(class: "h-1.5 w-1.5 shrink-0 rounded-full #{classes}", "aria-hidden": "true") if classes
      end
    end
  end
end
