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

      # @param align [Symbol] Alignment (default: :right)
      # @param width [Integer] Width (default: 48)
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
      # @return [String] CSS classes for dropdown panel
      def dropdown_classes
        align_class = align == :right ? "right-0" : "left-0"
        width_class = "w-#{width}"
        "absolute #{align_class} mt-2 #{width_class} origin-top-#{align} #{theme.border_radius} " \
          "#{theme.card_bg} border #{theme.card_border} #{theme.card_shadow}-lg z-50"
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
        # @return [String] CSS classes for menu item
        def item_classes
          base = "flex items-center gap-2 w-full px-4 py-2 text-sm text-left transition-colors duration-150"
          if destructive
            "#{base} text-red-600 hover:bg-red-50"
          else
            "#{base} text-gray-700 hover:bg-gray-50"
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

          helpers.heroicon(icon, variant: :outline, options: { class: "h-4 w-4" })
        end
      end
    end
  end
end
