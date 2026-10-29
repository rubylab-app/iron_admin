# frozen_string_literal: true

module IronAdmin
  module Ui
    # Renders a styled alert/notification message, colored by the theme's
    # +alert_palette+ entry for its type.
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

      # Icon of each type. The colors come from the theme's +alert_palette+.
      # @return [Hash{Symbol => Hash}]
      TYPES = {
        success: { icon: "check-circle" },
        error: { icon: "x-circle" },
        warning: { icon: "exclamation-triangle" },
        info: { icon: "information-circle" },
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
        TYPES[palette_type]
      end

      # @api private
      # @return [String] CSS classes for alert container: the theme's palette
      #   entry for the type (else its +:info+ entry), border width, radius and alert shadow
      def alert_classes
        palette = theme.alert_palette.to_h
        colors = palette[palette_type] || palette[:info]
        "#{colors} #{theme.border_width} #{theme.border_radius} #{theme.alert_shadow} px-4 py-3"
      end

      # @api private
      # @return [String] CSS classes for the dismiss button
      def dismiss_classes
        "-m-1 shrink-0 p-1 opacity-70 transition-opacity hover:opacity-100 #{theme.control_radius} #{theme.focus_ring}"
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
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [Symbol] The alert type, or +:info+ for an unknown one
      def palette_type
        TYPES.key?(@type) ? @type : :info
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
