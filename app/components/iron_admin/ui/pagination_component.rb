# frozen_string_literal: true

module IronAdmin
  module Ui
    # Renders pagination controls for record lists.
    #
    # Uses Pagy (>= 43) for pagination logic. The pagy object must come from
    # the +pagy+ controller method (Pagy::Method), so that it carries the
    # request needed to build page URLs.
    #
    # @example Basic pagination
    #   render IronAdmin::Ui::PaginationComponent.new(pagy: @pagy)
    class PaginationComponent < ViewComponent::Base
      # Size, shape and type of every page and prev/next link; the theme adds
      # their border width, radius and colors.
      # @return [String]
      ITEM_CLASSES = "inline-flex h-8 min-w-8 items-center justify-center px-2 text-sm font-medium tabular-nums " \
                     "transition-colors duration-150"

      # @return [Pagy] The Pagy pagination object
      attr_reader :pagy_obj

      # @param pagy [Pagy] Pagination object
      def initialize(pagy:)
        @pagy_obj = pagy
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [Boolean] Whether to render pagination
      def render?
        pagy_obj.pages > 1
      end

      # @api private
      # Page numbers, the current page as a String, and :gap markers,
      # e.g. [1, :gap, 7, "8", 9, :gap, 36]. Pagy keeps #series protected; its
      # custom-nav demo (apps/demo.ru) calls it via #send too.
      # @return [Array<Integer, String, Symbol>]
      def series
        pagy_obj.send(:series)
      end

      # @!method page_url(page)
      #   @api private
      #   @param page [Integer] Page number
      #   @return [String] URL for the page, preserving the current query params
      delegate :page_url, to: :pagy_obj

      # @api private
      # @param active [Boolean] Whether this is the current page
      # @return [String] CSS classes for page number links: the theme's
      #   +pagination_active+ for the current page, else a ghost link
      def page_link_classes(active: false)
        if active
          "#{item_base} #{theme.pagination_active}"
        else
          "#{item_base} border-transparent #{theme.body_text} #{theme.item_hover} #{theme.focus_ring}"
        end
      end

      # @api private
      # @param disabled [Boolean] Whether nav link is disabled
      # @return [String] CSS classes for prev/next navigation links
      def nav_link_classes(disabled: false)
        if disabled
          "#{item_base} border-transparent #{theme.disabled_text} cursor-not-allowed"
        else
          "#{item_base} border-transparent #{theme.body_text} #{theme.item_hover} #{theme.focus_ring}"
        end
      end

      # @api private
      # @return [String] CSS classes for the gap between page numbers
      def gap_classes
        "#{item_base} border-transparent #{theme.muted_text} cursor-default"
      end

      private

      def item_base
        "#{ITEM_CLASSES} #{theme.border_width} #{theme.control_radius}"
      end
    end
  end
end
