# frozen_string_literal: true

module IronAdmin
  module Dashboards
    # Renders a quick links section on the dashboard.
    class QuickLinksComponent < ViewComponent::Base
      include Concerns::ThemedCard

      renders_many :links, "LinkComponent"

      # @return [String] Section title
      attr_reader :title

      # @param title [String] Title (default: "Quick Links")
      def initialize(title: "Quick Links")
        @title = title
      end

      # @api private
      # @return [Boolean] Whether to render the component
      def render?
        links.any?
      end

      # Individual quick link item component.
      # @api private
      class LinkComponent < ViewComponent::Base
        include Concerns::ThemedCard

        # @return [String] Link label
        attr_reader :label

        # @return [String] Link URL
        attr_reader :href

        # @return [String, nil] Optional icon name
        attr_reader :icon

        # @return [String, nil] Optional description
        attr_reader :description

        # @param label [String] Link label
        # @param href [String] Link URL
        # @param icon [String, nil] Optional Heroicon name
        # @param description [String, nil] Optional description
        def initialize(label:, href:, icon: nil, description: nil)
          @label = label
          @href = href
          @icon = icon
          @description = description
        end
      end
    end
  end
end
