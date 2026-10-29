# Components Library

IronAdmin includes a comprehensive library of ViewComponents for building admin interfaces. All components use Tailwind CSS classes and are designed to work with the theming system.

## Component Categories

| Category | Components | Purpose |
|----------|------------|---------|
| [UI Components](ui-components.md) | Badge, Button, Card, Alert, Modal, Dropdown, Tooltip, Pagination | Core UI elements |
| [Form Components](form-components.md) | TextInput, Select, Checkbox, Textarea, DatePicker, BelongsTo | Form inputs |
| [Filter Components](filter-components.md) | Search, SelectFilter, DateRange, FilterBar | Data filtering |
| [Resource Components](resource-components.md) | DataTable, ShowField, Actions, Breadcrumb, BulkActions | Resource views |
| [Dashboard Components](dashboard-components.md) | Chart, StatsGrid, ActivityFeed, QuickLinks, MetricCard | Dashboard widgets |

## Using Components

All components live under the `IronAdmin` namespace and are organized by category:

```ruby
# UI Components
IronAdmin::Ui::BadgeComponent
IronAdmin::Ui::ButtonComponent
IronAdmin::Ui::CardComponent

# Form Components
IronAdmin::Form::TextInputComponent
IronAdmin::Form::SelectComponent

# Filter Components
IronAdmin::Filters::SearchComponent
IronAdmin::Filters::SelectFilterComponent

# Resource Components
IronAdmin::Resources::DataTableComponent
IronAdmin::Resources::BreadcrumbComponent

# Dashboard Components
IronAdmin::Dashboards::ChartComponent
IronAdmin::Dashboards::StatsGridComponent
```

## Rendering Components

Components can be rendered in views using ViewComponent's `render` helper:

```haml
= render IronAdmin::Ui::BadgeComponent.new(text: "Active", color: :green)

= render IronAdmin::Ui::ButtonComponent.new(text: "Save", variant: :primary)
```

## Theme Integration

All components use the theme of the current request (`IronAdmin.current_theme`), so they follow
the theme switcher. Inside the built-in components, the `theme` method returns it:

```ruby
def card_classes
  "#{theme.card_bg} #{theme.border_width} #{theme.card_border} #{theme.border_radius}"
end
```

In components of your own, read `IronAdmin.current_theme` too (see
[Using the theme in your own components](../guides/theming.md#using-the-theme-in-your-own-components)).

## Overriding Components

Override any component globally or per-resource. See [Components Guide](../guides/components.md) for details.
