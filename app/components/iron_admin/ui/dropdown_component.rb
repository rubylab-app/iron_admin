# frozen_string_literal: true

module IronAdmin
  module Ui
    # Renders a dropdown menu with trigger and items.
    #
    # @example Basic dropdown
    #   render IronAdmin::Ui::DropdownComponent.new do |dropdown|
    #     dropdown.with_trigger { render ButtonComponent.new(text: "Actions") }
    #     dropdown.with_item(href: edit_path) { "Edit" }
    #     dropdown.with_item(href: delete_path, destructive: true) { "Delete" }
    #   end
    class DropdownComponent < ViewComponent::Base
      renders_one :trigger
      renders_many :items, "ItemComponent"

      # @return [Symbol] Dropdown alignment (:left, :right)
      attr_reader :align

      # @return [Integer] Dropdown width in Tailwind units
      attr_reader :width

      # Width class of each supported +width+. Tailwind generates only the class
      # names written in full in the engine's sources, so others fall back to w-48.
      # @return [Hash{Integer => String}]
      WIDTHS = {
        32 => "w-32", 40 => "w-40", 44 => "w-44", 48 => "w-48", 52 => "w-52", 56 => "w-56",
        60 => "w-60", 64 => "w-64", 72 => "w-72", 80 => "w-80", 96 => "w-96",
      }.freeze

      # Position and transform origin of each alignment.
      # @return [Hash{Symbol => String}]
      ALIGNMENTS = { right: "right-0 origin-top-right", left: "left-0 origin-top-left" }.freeze

      # @param align [Symbol] Alignment (default: :right)
      # @param width [Integer] Width in Tailwind units, one of {WIDTHS} (default: 48)
      def initialize(align: :right, width: 48)
        @align = align
        @width = width
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] CSS classes for dropdown panel: a theme surface lifted
      #   by the theme's +popover_shadow+
      def dropdown_classes
        position = ALIGNMENTS[align.to_sym] || ALIGNMENTS[:right]
        "absolute #{position} z-50 mt-1.5 #{WIDTHS.fetch(width, "w-48")} p-1 #{theme.card_bg} " \
          "#{theme.border_width} #{theme.card_border} #{theme.border_radius} #{theme.popover_shadow}"
      end

      # Individual dropdown menu item.
      # @api private
      class ItemComponent < ViewComponent::Base
        # @return [String, nil] Link URL
        attr_reader :href

        # @return [Symbol, nil] HTTP method
        attr_reader :method

        # @return [String, nil] Heroicon name
        attr_reader :icon

        # @return [Boolean] Whether item is destructive (red styling)
        attr_reader :destructive

        # @param href [String, nil] Link URL
        # @param method [Symbol, nil] HTTP method
        # @param icon [String, nil] Heroicon name
        # @param destructive [Boolean] Destructive action (default: false)
        def initialize(href: nil, method: nil, icon: nil, destructive: false)
          @href = href
          @method = method
          @icon = icon
          @destructive = destructive
        end

        # @api private
        # @return [IronAdmin::Configuration::Theme] Theme of the current request
        def theme
          IronAdmin.current_theme
        end

        # @api private
        # @return [String] CSS classes for menu item: the theme's +danger_item+
        #   when destructive, else its body text and +item_hover+
        def item_classes
          base = "flex w-full items-center gap-2 px-2 py-1.5 text-left text-sm transition-colors duration-150 " \
                 "#{theme.control_radius} #{theme.focus_ring}"
          if destructive
            "#{base} #{theme.danger_item}"
          else
            "#{base} #{theme.body_text} #{theme.item_hover}"
          end
        end

        # Renders the menu item.
        # @return [String] HTML content
        def call
          if href
            link_to(href, class: item_classes, data: method ? { turbo_method: method } : {}) do
              item_content
            end
          else
            tag.button(type: "button", class: item_classes) do
              item_content
            end
          end
        end

        private

        def item_content
          safe_join([icon_element, content].compact)
        end

        def icon_element
          return unless icon

          classes = destructive ? "h-4 w-4 shrink-0" : "h-4 w-4 shrink-0 #{theme.icon_muted}"
          helpers.heroicon(icon, variant: :outline, options: { class: classes })
        end
      end
    end
  end
end
