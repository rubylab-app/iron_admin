# frozen_string_literal: true

module IronAdmin
  # Base class for defining the admin dashboard.
  #
  # The dashboard is the landing page of the admin panel and typically
  # displays key metrics, charts, and recent records. Create a subclass
  # of Dashboard to customize what appears on your admin home page.
  #
  # Only one Dashboard subclass should exist per application. When defined,
  # it automatically registers itself as the active dashboard.
  #
  # @example Basic dashboard
  #   class AdminDashboard < IronAdmin::Dashboard
  #     metric :total_users, format: :number do
  #       User.count
  #     end
  #
  #     metric :revenue, format: :currency do
  #       Order.sum(:total)
  #     end
  #
  #     chart :signups_by_month, type: :bar do
  #       User.group_by_month(:created_at).count
  #     end
  #
  #     recent :orders, limit: 10
  #     recent :users, limit: 5
  #   end
  #
  # @example Dashboard with custom layout
  #   class AdminDashboard < IronAdmin::Dashboard
  #     metric :active_users do
  #       User.where(active: true).count
  #     end
  #
  #     chart :orders_by_day, type: :line do
  #       Order.group_by_day(:created_at).count
  #     end
  #
  #     layout do
  #       # Define custom grid layout
  #     end
  #   end
  class Dashboard
    class_attribute :defined_metrics, default: []
    class_attribute :defined_charts, default: []
    class_attribute :defined_recents, default: []
    class_attribute :defined_progress_bars, default: []
    class_attribute :_layout_block, default: nil

    class << self
      # @api private
      # Automatically registers subclasses as the active dashboard.
      def inherited(subclass)
        super
        IronAdmin.dashboard_class = subclass
      end

      # Defines a metric card for the dashboard.
      #
      # Metrics are displayed as cards showing a single value with a label.
      # They're useful for key performance indicators and summary statistics.
      #
      # @param name [Symbol] The metric identifier (used as the card title)
      # @param format [Symbol] How to format the value
      #   - :number - Plain number with thousands separators
      #   - :currency - Currency format (uses Rails number_to_currency)
      #   - :percentage - Percentage format
      # @param icon [String, nil] Optional Heroicon name for visual context (e.g., "users", "currency-dollar")
      # @yield Block that computes and returns the metric value
      # @yieldreturn [Numeric] The metric value
      #
      # @example User count metric with icon
      #   metric :total_users, format: :number, icon: "users" do
      #     User.count
      #   end
      #
      # @example Revenue metric
      #   metric :total_revenue, format: :currency do
      #     Order.where(status: "completed").sum(:total)
      #   end
      #
      # @return [void]
      def metric(name, format: :number, icon: nil, live: false, &block)
        self.defined_metrics = defined_metrics + [{ name: name, format: format, icon: icon, live: live, block: block }]
      end

      # Defines a chart for the dashboard.
      #
      # Charts display time-series or categorical data visually.
      # The block should return data in a format suitable for the chart type.
      #
      # @param name [Symbol] The chart identifier
      # @param type [Symbol] The chart type
      #   - :line - Line chart for trends over time
      #   - :area - Filled line chart, emphasizes volume over time
      #   - :bar - Vertical bar chart for comparisons
      #   - :horizontal_bar - Horizontal bar chart, good for long category labels
      #   - :pie - Pie chart for proportions
      #   - :doughnut - Doughnut chart for proportions
      #   - :radar - Radar chart for multivariate comparisons
      #   - :polar_area - Polar area chart for proportions with magnitude
      # @param colors [Array<String>, nil] Optional per-chart color palette (CSS color values).
      #   Overrides the global theme chart_colors for this chart.
      # @param label [String, nil] Custom display title for the chart.
      #   Defaults to `name.to_s.humanize` when not provided.
      # @yield Block that computes and returns the chart data
      # @yieldreturn [Hash, Array] Data for the chart (format depends on type)
      #
      # @example Chart with custom label
      #   chart :projects_by_status, type: :bar, label: "Projects by Status" do
      #     Project.group(:status).count
      #   end
      #
      # @example Bar chart with custom colors
      #   chart :orders_by_status, type: :bar, colors: ["#10b981", "#3b82f6", "#ef4444"] do
      #     Order.group(:status).count
      #   end
      #
      # @return [void]
      def chart(name, type: :line, colors: nil, label: nil, live: false, &block)
        self.defined_charts = defined_charts + [
          { name: name, type: type, colors: colors, label: label, live: live, block: block },
        ]
      end

      # Defines a progress (gauge) widget for the dashboard.
      #
      # Progress widgets show a single value as a proportion of a target,
      # rendered as a horizontal bar with the value, target, and percentage.
      # They're useful for goals, quotas, capacity, and completion rates.
      #
      # @param name [Symbol] The widget identifier (used as the label)
      # @param max [Numeric] The target/maximum value the bar fills toward (default: 100)
      # @param format [Symbol] How to format the value and target
      #   - :number - Plain number with thousands separators
      #   - :currency - Currency format (uses Rails number_to_currency)
      #   - :percentage - Percentage format
      # @param label [String, nil] Custom display title. Defaults to `name.to_s.humanize`.
      # @param color [String, nil] Optional CSS color for the filled bar.
      #   Defaults to the theme chart border color.
      # @yield Block that computes and returns the current value
      # @yieldreturn [Numeric] The current value
      #
      # @example Monthly signups toward a goal
      #   progress :monthly_signups, max: 500 do
      #     User.where(created_at: Time.current.all_month).count
      #   end
      #
      # @example Revenue goal with currency formatting
      #   progress :revenue_goal, max: 100_000, format: :currency, label: "Revenue Goal" do
      #     Order.this_month.sum(:total)
      #   end
      #
      # @return [void]
      def progress(name, max: 100, format: :number, label: nil, color: nil, &block)
        self.defined_progress_bars = defined_progress_bars + [
          { name: name, max: max, format: format, label: label, color: color, block: block },
        ]
      end

      # Displays a list of recent records from a resource.
      #
      # Shows a table of the most recent records, with links to view each one.
      # Useful for quick access to newly created or updated items.
      #
      # @param resource_name [Symbol] The resource name (pluralized, e.g., :orders)
      # @param limit [Integer] Maximum number of records to show (default: 5)
      # @param scope [Proc, nil] Optional scope to filter records
      #
      # @example Recent orders
      #   recent :orders, limit: 10
      #
      # @example Recent pending orders
      #   recent :orders, limit: 5, scope: -> { where(status: "pending") }
      #
      # @example Recent active users
      #   recent :users, limit: 5, scope: -> { where(active: true) }
      #
      # @return [void]
      def recent(resource_name, limit: 5, scope: nil)
        self.defined_recents = defined_recents + [{ resource_name: resource_name, limit: limit, scope: scope }]
      end

      # Defines a custom layout for the dashboard.
      #
      # Use this to control the arrangement of metrics, charts, and
      # recent record lists on the dashboard page.
      #
      # @yield Block that defines the layout structure
      #
      # @example Custom two-column layout
      #   layout do
      #     # Layout definition
      #   end
      #
      # @return [void]
      def layout(&block)
        self._layout_block = block
      end
    end
  end
end
