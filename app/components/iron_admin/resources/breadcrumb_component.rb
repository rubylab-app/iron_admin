# frozen_string_literal: true

module IronAdmin
  module Resources
    # Renders breadcrumb navigation.
    class BreadcrumbComponent < ViewComponent::Base
      renders_many :items, "ItemComponent"

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # Individual breadcrumb item component.
      # @api private
      class ItemComponent < ViewComponent::Base
        # @return [String] Item label text
        attr_reader :label

        # @return [String, nil] Item link URL
        attr_reader :href

        # @return [Boolean] Whether this is the current page
        attr_reader :current

        # @param label [String] Item label
        # @param href [String, nil] Item link URL
        # @param current [Boolean] Whether this is current page
        def initialize(label:, href: nil, current: false)
          @label = label
          @href = href
          @current = current
        end

        # @api private
        # @return [IronAdmin::Configuration::Theme] Theme of the current request
        def theme
          IronAdmin.current_theme
        end

        # @api private
        # @return [String] CSS classes for breadcrumb item
        def item_classes
          if current
            "text-sm font-medium #{theme.body_text}"
          else
            "text-sm #{theme.link}"
          end
        end

        # Renders the breadcrumb item.
        # @return [String] HTML content
        def call
          if href && !current
            link_to(label, href, class: item_classes)
          else
            tag.span(label, class: item_classes, aria: current ? { current: "page" } : {})
          end
        end
      end
    end
  end
end
