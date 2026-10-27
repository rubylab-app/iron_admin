# frozen_string_literal: true

module IronAdmin
  # Dashboard components for rendering metrics, charts, and activity feeds.
  module Dashboards
    # Renders a chart on the dashboard.
    class ChartComponent < ViewComponent::Base
      # @return [String] Chart title
      attr_reader :title

      # @return [Symbol] Chart type
      #   (:line, :area, :bar, :horizontal_bar, :pie, :doughnut, :radar, :polar_area)
      attr_reader :type

      # @return [Array] Chart data
      attr_reader :data

      # @return [Array] Chart labels
      attr_reader :labels

      # @return [Integer] Chart height in pixels
      attr_reader :height

      # Supported chart types.
      # @return [Array<Symbol>]
      TYPES = %i[line area bar horizontal_bar pie doughnut radar polar_area].freeze

      # Maps IronAdmin chart types to their underlying Chart.js type strings.
      # Types not listed here map to themselves.
      # @return [Hash{Symbol=>Symbol}]
      CHART_JS_TYPES = { area: :line, horizontal_bar: :bar, polar_area: :polarArea }.freeze

      # Single-series types that render one line/shape with a border color and a
      # semi-transparent fill, rather than a per-slice color palette.
      # @return [Array<Symbol>]
      SINGLE_SERIES_TYPES = %i[line area radar].freeze

      # Types whose area is filled by default. `:line` stays filled for
      # backward compatibility (it was filled before `:area` was introduced);
      # `:area` is the explicit, intention-revealing name for a filled line.
      # @return [Array<Symbol>]
      FILLED_TYPES = %i[line area radar].freeze

      # Types that display a legend (multi-slice proportion charts).
      # @return [Array<Symbol>]
      LEGEND_TYPES = %i[pie doughnut polar_area].freeze

      # Types drawn on x and y axes.
      # @return [Array<Symbol>]
      CARTESIAN_TYPES = %i[line area bar horizontal_bar].freeze

      # Types drawn on a radial scale.
      # @return [Array<Symbol>]
      RADIAL_TYPES = %i[radar polar_area].freeze

      # @param title [String] Chart title
      # @param type [Symbol] Chart type (default: :line)
      # @param data [Array] Chart data
      # @param labels [Array] Chart labels
      # @param colors [Array<String>, nil] Per-chart color palette (overrides theme)
      # @param height [Integer] Height (default: 300)
      def initialize(title:, type: :line, data: [], labels: [], colors: nil, height: 300)
        @title = title
        @type = type.to_sym
        @data = data
        @labels = labels
        @colors = colors
        @height = height
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] Unique chart element ID
      def chart_id
        "chart-#{object_id}"
      end

      # @api private
      # @return [String] Chart.js configuration JSON
      def chart_config
        border = resolved_border_color
        {
          type: chart_js_type,
          data: {
            labels: labels,
            datasets: [{
              data: data,
              borderColor: border,
              backgroundColor: dataset_background(border),
              fill: filled?,
              tension: 0.3,
            }],
          },
          options: chart_options,
        }.to_json
      end

      # @api private
      # @return [Symbol] Underlying Chart.js type string for this chart type
      def chart_js_type
        CHART_JS_TYPES.fetch(type, type)
      end

      # @api private
      # @return [Boolean] Whether the dataset area is filled
      def filled?
        FILLED_TYPES.include?(type)
      end

      # @api private
      # @return [Boolean] Whether a legend is displayed for this chart type
      def legend?
        LEGEND_TYPES.include?(type)
      end

      # @api private
      # @return [String] Primary axis ("y" for horizontal bars, otherwise "x")
      def index_axis
        type == :horizontal_bar ? "y" : "x"
      end

      # Resolves chart colors with priority: per-chart > theme > default.
      # @api private
      # @return [Array<String>] Resolved chart color palette
      def chart_colors
        resolved_colors
      end

      private

      # Grid, tick and legend colors come from the theme, so dark themes get readable charts.
      # @return [Hash] Chart.js options
      def chart_options
        options = {
          responsive: true,
          maintainAspectRatio: false,
          indexAxis: index_axis,
          plugins: {
            legend: { display: legend?, labels: { color: theme.chart_text_color } },
          },
        }
        scales = scale_options
        scales ? options.merge(scales: scales) : options
      end

      # Pie and doughnut charts get no scales: Chart.js would draw axes for them.
      # @return [Hash, nil] Chart.js scale options in the theme's colors
      def scale_options
        grid = theme.chart_grid_color
        text = theme.chart_text_color
        if CARTESIAN_TYPES.include?(type)
          axis = { grid: { color: grid }, border: { color: grid }, ticks: { color: text } }
          { x: axis, y: axis }
        elsif RADIAL_TYPES.include?(type)
          ticks = { color: text, backdropColor: "transparent" }
          { r: { grid: { color: grid }, angleLines: { color: grid }, pointLabels: { color: text }, ticks: ticks } }
        end
      end

      # Resolves the dataset background: a single semi-transparent fill for
      # single-series charts, or the full color palette for multi-slice charts.
      # @param border [String] Resolved border color
      # @return [String, Array<String>] Background color(s) for the dataset
      def dataset_background(border)
        SINGLE_SERIES_TYPES.include?(type) ? line_fill_color(border) : resolved_colors
      end

      # @return [Array<String>] Color palette resolved from per-chart, theme, or default
      def resolved_colors
        @colors || theme.chart_colors
      end

      # @return [String] Border color resolved from per-chart first color or theme
      def resolved_border_color
        @colors&.first || theme.chart_border_color
      end

      # Converts a CSS color to a semi-transparent version for line chart fill.
      # Supports hex (#rrggbb), rgb(), and rgba() formats.
      # @param color [String] CSS color value
      # @return [String] Color with 0.1 opacity
      def line_fill_color(color)
        if color.start_with?("#")
          "#{color}1A"
        elsif color.start_with?("rgba")
          color.sub(/[\d.]+\)$/, "0.1)")
        elsif color.start_with?("rgb")
          color.sub("rgb(", "rgba(").sub(")", ", 0.1)")
        else
          color
        end
      end
    end
  end
end
