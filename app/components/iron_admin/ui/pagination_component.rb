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
      # @return [Pagy] The Pagy pagination object
      attr_reader :pagy_obj

      # @param pagy [Pagy] Pagination object
      def initialize(pagy:)
        @pagy_obj = pagy
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme configuration
      def theme
        IronAdmin.configuration.theme
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
      # @return [String] CSS classes for page number links
      def page_link_classes(active: false)
        base = "px-3 py-2 text-sm font-medium border transition-colors duration-150"
        if active
          "#{base} bg-indigo-50 border-indigo-500 text-indigo-600 z-10"
        else
          "#{base} #{theme.card_bg} #{theme.card_border} #{theme.body_text} hover:bg-gray-50"
        end
      end

      # @api private
      # @param disabled [Boolean] Whether nav link is disabled
      # @return [String] CSS classes for prev/next navigation links
      def nav_link_classes(disabled: false)
        base = "relative inline-flex items-center px-3 py-2 text-sm font-medium border transition-colors duration-150"
        if disabled
          "#{base} #{theme.card_bg} #{theme.card_border} text-gray-300 cursor-not-allowed"
        else
          "#{base} #{theme.card_bg} #{theme.card_border} #{theme.body_text} hover:bg-gray-50"
        end
      end
    end
  end
end
