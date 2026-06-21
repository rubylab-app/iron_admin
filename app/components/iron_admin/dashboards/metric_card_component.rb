# frozen_string_literal: true

module IronAdmin
  module Dashboards
    # Renders a metric card with name and formatted value.
    class MetricCardComponent < ViewComponent::Base
      # @param name [String, Symbol] Metric name
      # @param value [Numeric] Metric value
      # @param format [Symbol] Format (:number, :currency, :percentage)
      # @param icon [String, nil] Optional Heroicon name (e.g., "users", "currency-dollar")
      # @param live [Boolean] Whether to render a stable Turbo Stream target id
      def initialize(name:, value:, format: :number, icon: nil, live: false)
        @name = name
        @value = value
        @format = format
        @icon = icon
        @live = live
      end

      # @api private
      # @return [String] Value formatted according to format option
      def formatted_value
        case @format
        when :currency then helpers.number_to_currency(@value)
        when :percentage then helpers.number_to_percentage(@value, precision: 1)
        else helpers.number_with_delimiter(@value)
        end
      end

      # @api private
      # @return [String] Humanized metric label
      def label
        @name.to_s.humanize
      end

      # @api private
      # @return [Boolean] True when the metric should expose a live target
      def live?
        @live
      end

      # @api private
      # @return [String] Stable Turbo Stream target id
      def live_target_id
        "metric_#{@name.to_s.parameterize(separator: "_")}"
      end

      # @api private
      # @return [String, nil] Heroicon name
      attr_reader :icon
    end
  end
end
