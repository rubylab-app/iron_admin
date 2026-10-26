# frozen_string_literal: true

module IronAdmin
  module Layout
    # Renders the request's flash messages as dismissible {IronAdmin::Ui::AlertComponent}s.
    # {ShellComponent} renders it above the page content; a custom shell can too.
    #
    # Every message uses +role="alert"+: it arrives already written in a new
    # page, and screen readers do not announce an inserted +role="status"+.
    #
    # @example In a custom shell template
    #   = render IronAdmin::Layout::FlashComponent.new
    #   = content
    class FlashComponent < ViewComponent::Base
      # Flash keys that are shown, with the alert type of each. Other keys and
      # non-string values (such as Devise's +timedout+) are skipped.
      # @return [Hash{String => Symbol}]
      TYPES = {
        "notice" => :success,
        "success" => :success,
        "alert" => :error,
        "error" => :error,
        "warning" => :warning,
        "info" => :info,
      }.freeze

      # @param flash [ActionDispatch::Flash::FlashHash, Hash, nil] Messages to show
      #   (default: the current request's flash)
      def initialize(flash: nil)
        @flash = flash
      end

      # @api private
      # @return [Array<Array(Symbol, String)>] Alert type and text of each message, in flash order
      def messages
        @messages ||= (@flash || helpers.flash).flat_map do |key, value|
          type = TYPES[key.to_s]
          next [] unless type

          Array.wrap(value).grep(String).compact_blank.map { |message| [type, message] }
        end
      end

      # @api private
      # @return [Boolean] Whether there is a message to show
      def render?
        messages.any?
      end
    end
  end
end
