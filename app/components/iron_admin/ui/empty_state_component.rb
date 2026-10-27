# frozen_string_literal: true

module IronAdmin
  module Ui
    # Renders an empty state placeholder when no records exist.
    #
    # @example Basic empty state
    #   render IronAdmin::Ui::EmptyStateComponent.new(
    #     title: "No users yet",
    #     description: "Get started by creating your first user."
    #   )
    class EmptyStateComponent < ViewComponent::Base
      # @return [String] Title text
      attr_reader :title

      # @return [String, nil] Description text
      attr_reader :description

      # @return [String] Heroicon name
      attr_reader :icon

      # @return [String, nil] Action button text
      attr_reader :action_text

      # @return [String, nil] Action button URL
      attr_reader :action_href

      # @param title [String] Title (default: "No results found")
      # @param description [String, nil] Description
      # @param icon [String] Icon name (default: "inbox")
      # @param action_text [String, nil] Button text
      # @param action_href [String, nil] Button URL
      def initialize(title: "No results found", description: nil, icon: "inbox",
                     action_text: nil, action_href: nil)
        @title = title
        @description = description
        @icon = icon
        @action_text = action_text
        @action_href = action_href
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [Boolean] Whether action button should be shown
      def has_action?
        action_text.present? && action_href.present?
      end
    end
  end
end
