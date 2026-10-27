# frozen_string_literal: true

module IronAdmin
  # Resource-related components for listing, showing, and editing records.
  module Resources
    # Renders the actions dropdown for a single record.
    class ActionsComponent < ViewComponent::Base
      # @return [Array<Hash>] Defined actions
      attr_reader :actions

      # @return [ActiveRecord::Base] The record
      attr_reader :record

      # @return [Class] The resource class
      attr_reader :resource_class

      # @param actions [Array<Hash>] Actions to render
      # @param record [ActiveRecord::Base] The record
      # @param resource_class [Class] The resource
      def initialize(actions:, record:, resource_class:)
        @actions = actions
        @record = record
        @resource_class = resource_class
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @param action [Hash] Action configuration
      # @return [String] URL for executing the action
      def action_url(action)
        helpers.iron_admin.resource_action_path(resource_class.resource_name, record, action[:name])
      end

      # @api private
      # @param action [Hash] Action configuration
      # @return [String] Text of the action's confirmation dialog
      def confirm_message(action)
        action[:confirm_message].presence || I18n.t("iron_admin.resources.action.confirm")
      end

      # @api private
      # @return [Boolean] Whether to render the component
      def render?
        actions.any?
      end
    end
  end
end
