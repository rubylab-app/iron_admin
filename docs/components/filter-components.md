# Filter Components

Components for filtering and searching data.

## SearchComponent

Search input with icon.

```ruby
IronAdmin::Filters::SearchComponent.new(
  form_url: "/admin/users",    # Required: form submit URL
  placeholder: "Search...",    # Optional: placeholder text
  value: nil,                  # Optional: current search query
  hidden_params: {}            # Optional: hidden form params to preserve
)
```

**Example:**

```haml
= render IronAdmin::Filters::SearchComponent.new(
  form_url: resources_path,
  placeholder: "Search users...",
  value: params[:q],
  hidden_params: { scope: params[:scope] }
)
```

---

## SelectFilterComponent

Dropdown filter for categorical data.

```ruby
IronAdmin::Filters::SelectFilterComponent.new(
  name: :status,               # Required: filter parameter name
  options: options,            # Required: array of [label, value] pairs
  label: nil,                  # Optional: label text (auto-generated from name)
  selected: nil                # Optional: currently selected value
)
```

**Example:**

```haml
= render IronAdmin::Filters::SelectFilterComponent.new(
  name: :role,
  options: [["Admin", "admin"], ["User", "user"], ["Guest", "guest"]],
  label: "User Role",
  selected: params.dig(:filters, :role)
)
```

---

## DateRangeComponent

Date range filter with from/to inputs.

```ruby
IronAdmin::Filters::DateRangeComponent.new(
  name: :created_at,           # Required: filter parameter name
  label: nil,                  # Optional: label text (auto-generated from name)
  from_value: nil,             # Optional: from date value
  to_value: nil                # Optional: to date value
)
```

**Example:**

```haml
= render IronAdmin::Filters::DateRangeComponent.new(
  name: :created_at,
  label: "Created Between",
  from_value: params.dig(:filters, :created_at_from),
  to_value: params.dig(:filters, :created_at_to)
)
```

---

## StringFilterComponent

Text input with an operator dropdown for string matching.

```ruby
IronAdmin::Filters::StringFilterComponent.new(
  name: :name,                   # Required: filter parameter name
  label: nil,                    # Optional: label text (auto-generated from name)
  value: nil,                    # Optional: current filter value
  operator: "contains"           # Optional: current operator (default: "contains")
)
```

**Operators:** `contains`, `equals`, `starts_with`, `ends_with`

**Example:**

```haml
= render IronAdmin::Filters::StringFilterComponent.new(
  name: :name,
  label: "Customer Name",
  value: params.dig(:filters, :name),
  operator: params.dig(:filters, :name_operator) || "contains"
)
```

---

## NumberFilterComponent

Number input with an operator dropdown for numeric comparisons.

```ruby
IronAdmin::Filters::NumberFilterComponent.new(
  name: :price,                  # Required: filter parameter name
  label: nil,                    # Optional: label text (auto-generated from name)
  value: nil,                    # Optional: current filter value
  max_value: nil,                # Optional: upper bound for "between" operator
  operator: "equals"             # Optional: current operator (default: "equals")
)
```

**Operators:** `equals`, `greater_than`, `less_than`, `between`

When the `between` operator is selected, a second input for the upper bound is displayed.

**Example:**

```haml
= render IronAdmin::Filters::NumberFilterComponent.new(
  name: :price,
  label: "Price",
  value: params.dig(:filters, :price),
  max_value: params.dig(:filters, :price_max),
  operator: params.dig(:filters, :price_operator) || "equals"
)
```

---

## BarComponent

Container for filter controls with dropdown behavior.

```ruby
IronAdmin::Filters::BarComponent.new(
  form_url: "/admin/users",    # Required: form submit URL
  scope: nil,                  # Optional: current scope
  query: nil,                  # Optional: current search query
  active_count: 0              # Optional: number of active filters
)
```

**Slots:**
- `filters` - Individual filter components

**Example:**

```haml
= render IronAdmin::Filters::BarComponent.new(
  form_url: resources_path,
  active_count: @active_filter_count
) do |bar|

  - bar.with_filter do
    = render IronAdmin::Filters::SelectFilterComponent.new(
      name: :status,
      options: status_options,
      selected: params.dig(:filters, :status)
    )

  - bar.with_filter do
    = render IronAdmin::Filters::DateRangeComponent.new(
      name: :created_at,
      from_value: params.dig(:filters, :created_at_from),
      to_value: params.dig(:filters, :created_at_to)
    )
```

---

## Combining Filters

Typical filter bar setup:

```haml
.flex.items-center.gap-4
  -# Search
  = render IronAdmin::Filters::SearchComponent.new(
    form_url: resources_path,
    value: params[:q]
  )

  -# Filter dropdown
  = render IronAdmin::Filters::BarComponent.new(
    form_url: resources_path,
    active_count: active_filter_count
  ) do |bar|

    - bar.with_filter do
      = render IronAdmin::Filters::SelectFilterComponent.new(
        name: :role,
        options: role_options
      )

    - bar.with_filter do
      = render IronAdmin::Filters::DateRangeComponent.new(
        name: :created_at
      )
```
