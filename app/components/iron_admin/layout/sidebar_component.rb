# frozen_string_literal: true

module IronAdmin
  module Layout
    # Renders the sidebar navigation menu.
    class SidebarComponent < ViewComponent::Base
      include IronAdmin::ThemeHelper

      # @param current_user [Object, nil]
      def initialize(current_user: nil)
        @current_user = current_user
      end

      # Returns resources grouped by menu group.
      # Resources the current user cannot read are omitted.
      # @return [Hash{String => Array<Class>}]
      def grouped_resources
        IronAdmin::ResourceRegistry.grouped.each_with_object({}) do |(group, resources), visible|
          readable = resources.select { |resource| resource.crud_allowed?(:read, @current_user) }
          visible[group] = readable if readable.any?
        end
      end

      # Returns tools grouped by menu group.
      # @return [Hash{String => Array<Class>}]
      def grouped_tools
        IronAdmin::ToolRegistry.grouped
      end

      # @api private
      # @return [String] Configured admin panel title
      def title
        IronAdmin.configuration.title
      end

      # @api private
      # @return [String, nil] Configured logo URL or path
      def logo
        IronAdmin.configuration.logo
      end
    end
  end
end
