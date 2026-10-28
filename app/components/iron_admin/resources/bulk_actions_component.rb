# frozen_string_literal: true

module IronAdmin
  module Resources
    # Renders the bulk actions dropdown for selected records.
    class BulkActionsComponent < ViewComponent::Base
      # @return [Array<Hash>] Defined bulk actions
      attr_reader :actions

      # @return [Class] The resource class
      attr_reader :resource_class

      # @param actions [Array<Hash>] Bulk actions
      # @param resource_class [Class] The resource
      def initialize(actions:, resource_class:)
        @actions = actions
        @resource_class = resource_class
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] CSS classes of the toolbar, shown once records are selected
      def toolbar_classes
        "hidden flex-wrap items-center gap-3 px-4 py-3 border-t #{theme.card_bg} #{theme.card_border}"
      end

      # @api private
      # @return [String] CSS classes of an action button
      def button_classes
        Styles.secondary_button(theme)
      end

      # @api private
      # @param action [Hash] Bulk action configuration
      # @return [String] URL for executing the bulk action
      def action_url(action)
        helpers.iron_admin.resource_bulk_action_path(resource_class.resource_name, action[:name])
      end

      # @api private
      # @param action [Hash] Bulk action configuration
      # @return [Boolean] Whether the action has form fields, so its button opens the form
      def form?(action)
        action[:form_fields].present?
      end

      # @api private
      # @param action [Hash] Bulk action configuration
      # @return [String] URL of the bulk action's form
      def form_url(action)
        helpers.iron_admin.resource_bulk_action_form_path(resource_class.resource_name, action[:name])
      end

      # @api private
      # @param action [Hash] Bulk action configuration
      # @return [String] Text of the action's confirmation dialog
      def confirm_message(action)
        action[:confirm_message].presence || I18n.t("iron_admin.resources.action.confirm")
      end

      # @api private
      # @param action [Hash] Bulk action configuration
      # @return [Hash] Data attributes of the action's button: the confirmation of a confirm: true
      #   action without form fields (an action with form fields asks on its form's submit)
      def confirm_data(action)
        action[:confirm] && !form?(action) ? { turbo_confirm: confirm_message(action) } : {}
      end

      # @api private
      # @return [Boolean] Whether to render the component
      def render?
        actions.any?
      end
    end
  end
end
