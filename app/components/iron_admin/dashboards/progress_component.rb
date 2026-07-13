# frozen_string_literal: true

module IronAdmin
  module Dashboards
    # Renders a progress (gauge) widget showing a value as a proportion of a target.
    class ProgressComponent < ViewComponent::Base
      # @return [String] Widget title
      attr_reader :title

      # @return [Float] Current value
      attr_reader :value

      # @return [Float] Target/maximum value
      attr_reader :max

      # @return [Symbol] Value format (:number, :currency, :percentage)
      attr_reader :format

      # @param title [String] Widget title
      # @param value [Numeric] Current value
      # @param max [Numeric] Target/maximum value (default: 100)
      # @param format [Symbol] Value format (default: :number)
      # @param color [String, nil] CSS color for the filled bar (overrides theme)
      def initialize(title:, value:, max: 100, format: :number, color: nil)
        @title = title
        @value = value.to_f
        @max = max.to_f
        @format = format
        @color = color
      end

      # @api private
      # @return [Float] Completion percentage clamped to 0..100
      def percentage
        return 0.0 if max.zero?

        ((value / max) * 100).clamp(0, 100).round(1)
      end

      # @api private
      # @return [String] Current value formatted according to format option
      def formatted_value
        format_number(value)
      end

      # @api private
      # @return [String] Target value formatted according to format option
      def formatted_max
        format_number(max)
      end

      # @api private
      # @return [String] CSS color for the filled bar
      def bar_color
        @color || theme.chart_border_color
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme configuration
      def theme
        IronAdmin.configuration.theme
      end

      private

      # @param number [Numeric] The value to format
      # @return [String] Formatted value
      def format_number(number)
        case format
        when :currency then helpers.number_to_currency(number)
        when :percentage then helpers.number_to_percentage(number, precision: 1)
        else helpers.number_with_delimiter(number.to_i == number ? number.to_i : number)
        end
      end
    end
  end
end
