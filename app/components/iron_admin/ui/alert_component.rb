# frozen_string_literal: true

module IronAdmin
  module Ui
    # Renders a styled alert/notification message.
    #
    # @example Success alert
    #   render IronAdmin::Ui::AlertComponent.new(
    #     message: "Record saved successfully",
    #     type: :success
    #   )
    #
    # @example Error alert
    #   render IronAdmin::Ui::AlertComponent.new(
    #     message: "Something went wrong",
    #     type: :error
    #   )
    #
    # Errors and warnings use +role="alert"+ and the other types +role="status"+,
    # so screen readers announce them assertively or politely; +role:+ overrides
    # that. {IronAdmin::Layout::FlashComponent} always passes "alert". The dismiss
    # button uses the +cp-alert+ Stimulus controller.
    class AlertComponent < ViewComponent::Base
      # @return [String, nil] The alert message
      attr_reader :message

      # @return [Symbol] Alert type (:success, :error, :warning, :info)
      attr_reader :type

      # @return [Boolean] Whether alert can be dismissed
      attr_reader :dismissible

      # Type configurations with colors and icons.
      # @return [Hash{Symbol => Hash}]
      TYPES = {
        success: {
          bg: "bg-green-50",
          border: "border-green-200",
          text: "text-green-800",
          icon: "check-circle",
        },
        error: {
          bg: "bg-red-50",
          border: "border-red-200",
          text: "text-red-800",
          icon: "x-circle",
        },
        warning: {
          bg: "bg-yellow-50",
          border: "border-yellow-200",
          text: "text-yellow-800",
          icon: "exclamation-triangle",
        },
        info: {
          bg: "bg-blue-50",
          border: "border-blue-200",
          text: "text-blue-800",
          icon: "information-circle",
        },
      }.freeze

      # Types announced with +role="alert"+; the others use +role="status"+.
      # @return [Array<Symbol>]
      ASSERTIVE_TYPES = %i[error warning].freeze

      # @param message [String, nil] Alert message
      # @param type [Symbol] Alert type (default: :info)
      # @param dismissible [Boolean] Can be dismissed (default: true)
      # @param role [String, nil] ARIA role; overrides the role of the type
      def initialize(message: nil, type: :info, dismissible: true, role: nil)
        @message = message
        @type = type.to_sym
        @dismissible = dismissible
        @role = role
      end

      # @api private
      # @return [Hash] Configuration for the current alert type
      def type_config
        TYPES[@type] || TYPES[:info]
      end

      # @api private
      # @return [String] CSS classes for alert container
      def alert_classes
        "#{type_config[:bg]} #{type_config[:border]} #{type_config[:text]} border #{theme.border_radius} p-4"
      end

      # @api private
      # @return [String] ARIA role: the +role:+ given, else "alert" for errors
      #   and warnings and "status" otherwise
      def role
        @role || (ASSERTIVE_TYPES.include?(type) ? "alert" : "status")
      end

      # @api private
      # @return [String] Accessible label of the dismiss button
      def dismiss_label
        I18n.t("iron_admin.alerts.dismiss")
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme configuration
      def theme
        IronAdmin.configuration.theme
      end

      # @api private
      # @return [String] Heroicon name for alert type
      def icon_name
        type_config[:icon]
      end

      # @api private
      # @return [Boolean] Whether to render the component
      def render?
        message.present? || content.present?
      end
    end
  end
end
