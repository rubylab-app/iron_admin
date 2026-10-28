# Dashboard

The dashboard is the landing page of your admin panel, displaying key metrics, charts, and recent activity.

## Creating a Dashboard

Create a dashboard class in `app/iron_admin/dashboards/`:

```ruby
# app/iron_admin/dashboards/admin_dashboard.rb
class AdminDashboard < IronAdmin::Dashboard
  metric :total_users, format: :number do
    User.count
  end

  metric :monthly_revenue, format: :currency do
    Payment.where("created_at > ?", 30.days.ago).sum(:amount)
  end

  metric :conversion_rate, format: :percentage do
    total = User.count
    paying = User.joins(:subscriptions).distinct.count
    total.zero? ? 0 : (paying.to_f / total * 100).round(1)
  end

  recent :users, limit: 5, scope: -> { where(active: true) }
  recent :payments, limit: 10
end
```

## Metrics

Define metrics using the `metric` DSL:

```ruby
metric :name, format: :format_type do
  # Return a number
end
```

### Metric Formats

| Format | Display |
|--------|---------|
| `:number` | Plain number with commas (1,234) |
| `:currency` | Dollar formatted ($1,234.00) |
| `:percentage` | Percentage (12.5%) |

### Metric Component

Metrics render using `IronAdmin::Dashboards::MetricCardComponent`. Customize the display in your views:

```haml
= render IronAdmin::Dashboards::MetricCardComponent.new(
  name: :total_users,
  value: User.count,
  format: :number
)
```

## Charts

Define charts for visualizing trends:

```ruby
chart :signups_over_time, type: :line do
  # Return chart data
end
```

### Chart Types

- `:line` - Line chart
- `:bar` - Bar chart
- `:pie` - Pie chart
- `:doughnut` - Doughnut chart

### Chart Component

Charts render using `IronAdmin::Dashboards::ChartComponent`:

```haml
= render IronAdmin::Dashboards::ChartComponent.new(
  title: "Monthly Signups",
  type: :line,
  data: [45, 52, 38, 67, 89, 95],
  labels: ["Jan", "Feb", "Mar", "Apr", "May", "Jun"],
  height: 300
)
```

### Chart Colors

Charts take their colors from the current theme: `chart_colors` for slices (bar charts fill
every bar with its first color),
`chart_border_color` for lines, and `chart_grid_color` and `chart_text_color` for grid lines,
ticks and legends. These are CSS colors, not Tailwind classes, because Chart.js draws on a
canvas. A chart's own colors win over the theme, and a bar chart given its own colors fills its
bars with them one by one:

```ruby
chart :revenue, type: :bar, colors: ["#0ea5e9", "#6366f1"] do
  # ...
end
```

The first color is also the line color of line, area and radar charts. Charts draw their text
in the page's font. See [Color scheme, dark themes and charts](theming.md#color-scheme-dark-themes-and-charts).

## Recent Records

Show recent records from any resource:

```ruby
recent :resource_name, limit: 5, scope: -> { custom_scope }
```

The `resource_name` must match a registered resource's name (model's plural form).

**Access:** like the index page, the table is only rendered when the current user may read the
resource (`policy` and `deny_actions`), and `config.tenant_scope` applies to it, after the
`scope:`.

**Order:** records are listed newest first: by `created_at` descending, then by primary key
descending (by primary key alone when the model has no `created_at`). A `scope:` that calls
`order(...)` keeps its own order, for example `scope: -> { order(total: :desc) }`.

**Columns:** the table shows the resource's `index_fields` when it declares them. Otherwise it
shows up to four columns: the id, the label column (`name`, `title`, `email`, `label` or
`slug`), other short columns, and `created_at`. Long or sensitive types (`:textarea`,
`:rich_text`, `:markdown`, `:code`, `:json`, `:key_value`, `:boolean_group`, `:file`,
`:files`, `:password`, `:hidden`) are skipped. Like on the index page, fields hidden from the
current user are left out.

### Recent Table Component

Recent records render using `IronAdmin::Dashboards::RecentTableComponent`:

```haml
= render IronAdmin::Dashboards::RecentTableComponent.new(
  resource_name: :user,
  records: User.limit(5),
  current_user: iron_admin_current_user
)
```

`current_user:` is optional. Pass it so that fields with a `visible:` proc are checked for that
user; without it, the procs receive `nil`. An unordered relation is listed newest first, so
`User.order(created_at: :desc).limit(5)` is not needed, but still works.

## Stats Grid

Display multiple metrics in a responsive grid. With `columns: 4` (the default), the grid keeps two
columns until the `xl` breakpoint, like the metric cards, because the sidebar leaves too little room
for four at `lg`:

```haml
= render IronAdmin::Dashboards::StatsGridComponent.new(columns: 4) do |grid|
  - grid.with_stat(
    label: "Total Users",
    value: User.count,
    change: "+12%",
    change_type: :positive,
    icon: "users"
  )
  - grid.with_stat(
    label: "Revenue",
    value: number_to_currency(Payment.sum(:amount)),
    change: "-3%",
    change_type: :negative
  )
  - grid.with_stat(label: "Active Sessions", value: session_count)
  - grid.with_stat(label: "Conversion", value: "4.2%")
```

## Activity Feed

Show recent activity timeline:

```haml
= render IronAdmin::Dashboards::ActivityFeedComponent.new(title: "Recent Activity") do |feed|
  - @activities.each do |activity|
    - feed.with_item(
      description: activity.description,
      timestamp: activity.created_at,
      icon: "user",
      icon_color: :blue,
      href: activity_path(activity)
    )
```

## Quick Links

Add shortcut links to common actions:

```haml
= render IronAdmin::Dashboards::QuickLinksComponent.new(title: "Quick Actions") do |links|
  - links.with_link(label: "New User", href: new_user_path, icon: "user-plus")
  - links.with_link(label: "Export", href: export_path, icon: "arrow-down-tray")
  - links.with_link(label: "Settings", href: settings_path, icon: "cog-6-tooth")
```

## Registration

Only one dashboard can be active. The last class to inherit from `IronAdmin::Dashboard` becomes the active dashboard. Place your dashboard in `app/iron_admin/dashboards/`.

## Dashboard Components Reference

| Component | Purpose |
|-----------|---------|
| `MetricCardComponent` | Single metric display |
| `ChartComponent` | Charts (line, bar, pie) |
| `StatsGridComponent` | Grid of metrics |
| `RecentTableComponent` | Recent records table |
| `ActivityFeedComponent` | Activity timeline |
| `QuickLinksComponent` | Shortcut links |

See [Dashboard Components](../components/dashboard-components.md) for detailed documentation.
