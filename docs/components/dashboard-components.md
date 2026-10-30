# Dashboard Components

Widgets for building dashboard interfaces.

## ChartComponent

Charts using Chart.js (line, bar, pie, doughnut).

```ruby
IronAdmin::Dashboards::ChartComponent.new(
  title: "Revenue",           # Required: chart title
  type: :line,                # Optional: :line, :bar, :pie, :doughnut
  data: [100, 200, 300],      # Optional: array of values
  labels: ["Jan", "Feb", "Mar"], # Optional: array of labels
  height: 300                 # Optional: chart height in pixels
)
```

**Example:**

```haml
= render IronAdmin::Dashboards::ChartComponent.new(title: "Monthly Signups",
  type: :line,
  data: @monthly_signups.values,
  labels: @monthly_signups.keys,
  height: 250)

= render IronAdmin::Dashboards::ChartComponent.new(title: "Users by Role",
  type: :pie,
  data: @role_counts.values,
  labels: @role_counts.keys)
```

---

## StatsGridComponent

Grid of metric cards.

```ruby
IronAdmin::Dashboards::StatsGridComponent.new(
  columns: 4    # Optional: 2, 3, or 4 columns
)
```

The grid has one column on phones and two from `sm`. Three columns start at `lg` and four at
`xl`, as in the dashboard's metric grid: from `lg` the sidebar leaves the page about 700px, too
narrow for four cards. The cards are spaced like the metric cards (`gap-6`). In each card the label
wraps beside the icon, and the value sits on its own row below them.

**Slots:**
- `stats` - Individual stat items (renders `StatComponent`)

**StatComponent options:**
- `label` - Metric name
- `value` - Metric value
- `change` - Change indicator (e.g., "+12%")
- `change_type` - `:positive`, `:negative`, or `:neutral`
- `icon` - Heroicon name

**Example:**

```haml
= render IronAdmin::Dashboards::StatsGridComponent.new(columns: 4) do |grid|
  - grid.with_stat(label: "Total Users", value: @total_users, change: "+12%", change_type: :positive)
  - grid.with_stat(label: "Revenue", value: number_to_currency(@revenue), change: "-3%", change_type: :negative)
  - grid.with_stat(label: "Active Sessions", value: @active_sessions)
  - grid.with_stat(label: "Conversion Rate", value: "4.2%", icon: "chart-bar")
```

---

## ActivityFeedComponent

Timeline of recent activity.

```ruby
IronAdmin::Dashboards::ActivityFeedComponent.new(
  title: "Recent Activity"    # Optional: section title
)
```

**Slots:**
- `items` - Activity items (renders `ItemComponent`)

**ItemComponent options:**
- `description` - Activity description
- `timestamp` - Time or string
- `icon` - Heroicon name
- `icon_color` - a color name of the theme's `badge_palette` (`:green`, `:red`, `:yellow`, `:blue`, `:indigo`, `:purple`, `:pink`, `:orange`, `:teal` or `:gray`; default `:blue`). An unknown color uses `:gray`
- `href` - Optional link

**Example:**

```haml
= render IronAdmin::Dashboards::ActivityFeedComponent.new(title: "Recent Activity") do |feed|
  - @recent_activities.each do |activity|
    - feed.with_item(description: activity.description,
      timestamp: activity.created_at,
      icon: activity.icon,
      icon_color: activity.color,
      href: activity_path(activity))
```

---

## QuickLinksComponent

Grid of shortcut links.

```ruby
IronAdmin::Dashboards::QuickLinksComponent.new(
  title: "Quick Links"    # Optional: section title
)
```

**Slots:**
- `links` - Link items (renders `LinkComponent`)

**LinkComponent options:**
- `label` - Link text
- `href` - Link URL
- `icon` - Heroicon name
- `description` - Optional description

**Example:**

```haml
= render IronAdmin::Dashboards::QuickLinksComponent.new(title: "Quick Actions") do |links|
  - links.with_link(label: "New User", href: new_user_path, icon: "user-plus", description: "Create a new user account")
  - links.with_link(label: "Export Data", href: export_path, icon: "arrow-down-tray")
  - links.with_link(label: "Settings", href: settings_path, icon: "cog-6-tooth")
```

---

## MetricCardComponent

Single metric display card.

```ruby
IronAdmin::Dashboards::MetricCardComponent.new(
  name: :total_users,         # Required: metric name
  value: 1234,                # Required: metric value
  format: :number             # Optional: :number, :currency, :percentage
)
```

**Example:**

```haml
= render IronAdmin::Dashboards::MetricCardComponent.new(name: :monthly_revenue,
  value: 15000.50,
  format: :currency)
```

---

## RecentTableComponent

Table showing recent records from a resource.

```ruby
IronAdmin::Dashboards::RecentTableComponent.new(
  resource_name: :user,       # Required: resource name (singular)
  records: @recent_users,     # Required: records to display
  current_user: current_user  # Optional: user whose field visibility applies
)
```

- **Order:** a relation without an `order` is listed newest first (`created_at` descending,
  then primary key descending; primary key alone when there is no `created_at`). A relation
  with its own `order(...)`, or an Array, keeps its order.
- **Columns:** the resource's `index_fields` when it declares them. Otherwise up to four
  columns: the id, the label column (`name`, `title`, `email`, `label` or `slug`), other short
  columns, and `created_at`. Long or sensitive types (textarea, rich_text, markdown, code,
  json, key_value, boolean_group, file, files, password, hidden) are skipped.
- **Visibility:** fields with `visible:` are checked for `current_user:`. Without it, a
  `visible:` proc receives `nil`.

**Example:**

```haml
= render IronAdmin::Dashboards::RecentTableComponent.new(resource_name: :order,
  records: Order.limit(5),
  current_user: iron_admin_current_user)
```

---

## Building a Dashboard

Combine components to create a complete dashboard:

```haml
.space-y-8
  -# Stats row
  = render IronAdmin::Dashboards::StatsGridComponent.new(columns: 4) do |grid|
    - grid.with_stat(label: "Users", value: User.count)
    - grid.with_stat(label: "Revenue", value: number_to_currency(Payment.sum(:amount)))
    - grid.with_stat(label: "Orders", value: Order.count)
    - grid.with_stat(label: "Conversion", value: "3.2%")

  .grid.grid-cols-1.lg:grid-cols-2.gap-8
    -# Chart
    = render IronAdmin::Dashboards::ChartComponent.new(title: "Signups Over Time",
      type: :line,
      data: @signup_data,
      labels: @signup_labels)

    -# Activity feed
    = render IronAdmin::Dashboards::ActivityFeedComponent.new do |feed|
      - @activities.each do |a|
        - feed.with_item(description: a.message, timestamp: a.created_at)

  -# Recent tables
  .grid.grid-cols-1.lg:grid-cols-2.gap-8
    = render IronAdmin::Dashboards::RecentTableComponent.new(resource_name: :user,
      records: User.order(created_at: :desc).limit(5))

    = render IronAdmin::Dashboards::RecentTableComponent.new(resource_name: :order,
      records: Order.order(created_at: :desc).limit(5))
```
