# UI Components

Core UI elements for building admin interfaces.

## BadgeComponent

Displays a status in the current theme's colors: the `badge_palette` classes of its color, a
dot from `badge_dot_palette` (none when that Hash is empty) and the `badge_shape` radius and
weight. An unknown color uses `:gray`, and a color with classes in `config.badge_colors` uses
them, without a dot (see [Badges, alerts and chips](../guides/theming.md#badges-alerts-and-chips)).

```ruby
IronAdmin::Ui::BadgeComponent.new(
  text: "Active",      # Required: display text
  color: :green,       # Optional: a badge_palette key: :gray (default), :green, :red, :yellow, :blue, :indigo, :purple, :pink, :orange, :teal
  size: :md            # Optional: :sm, :md, :lg
)
```

**Example:**

```haml
= render IronAdmin::Ui::BadgeComponent.new(text: "Published", color: :green)
= render IronAdmin::Ui::BadgeComponent.new(text: "Draft", color: :yellow, size: :sm)
```

---

## ButtonComponent

Styled buttons with multiple variants and optional icons.

```ruby
IronAdmin::Ui::ButtonComponent.new(
  text: "Save",            # Optional: button text
  variant: :primary,       # Optional: :primary, :secondary, :danger, :ghost
  size: :md,               # Optional: :sm, :md, :lg
  icon: "check",           # Optional: Heroicon name
  href: "/path",           # Optional: renders as link instead of button
  method: :post,           # Optional: HTTP method for links (Turbo)
  confirm: "Are you sure?", # Optional: confirmation dialog
  type: :button,           # Optional: :button, :submit
  disabled: false          # Optional: disable the button
)
```

**Examples:**

```haml
-# Primary button
= render IronAdmin::Ui::ButtonComponent.new(text: "Save Changes", variant: :primary)

-# Danger button with confirmation
= render IronAdmin::Ui::ButtonComponent.new(
  text: "Delete",
  variant: :danger,
  icon: "trash",
  method: :delete,
  href: resource_path(@record),
  confirm: "This action cannot be undone."
)

-# Icon-only button
= render IronAdmin::Ui::ButtonComponent.new(icon: "pencil", variant: :ghost, size: :sm)
```

---

## CardComponent

Container with optional header and footer slots.

```ruby
IronAdmin::Ui::CardComponent.new(
  padding: true,    # Optional: add padding to content area
  shadow: true      # Optional: add shadow
)
```

**Slots:**
- `header` - Card header area
- `footer` - Card footer area

**Example:**

```haml
= render IronAdmin::Ui::CardComponent.new do |card|
  - card.with_header do
    %h3 User Details

  %p Card content goes here

  - card.with_footer do
    = render IronAdmin::Ui::ButtonComponent.new(text: "Save", variant: :primary)
```

---

## AlertComponent

Alert boxes and notifications. `IronAdmin::Layout::FlashComponent` renders each flash
message with it (see [Flash Messages](../guides/components.md#flash-messages)).

```ruby
IronAdmin::Ui::AlertComponent.new(
  message: "Success!",   # Optional: alert message (or pass a block as content)
  type: :success,        # Optional: :success, :error, :warning, :info (default: :info)
  dismissible: true,     # Optional: show close button (default: true)
  role: nil              # Optional: ARIA role, overrides the role of the type
)
```

- `:error` and `:warning` alerts have `role="alert"`, so screen readers announce them right
  away. `:success` and `:info` alerts have `role="status"` and are announced politely. Pass
  `role:` to override it. `IronAdmin::Layout::FlashComponent` passes `role: "alert"` for every
  flash message, because a message that arrives already written in a new page is not
  announced as a `status`.
- The colors come from the theme's `alert_palette` entry for the type (the `:info` entry for
  an unknown type), and the border width and radius from `border_width` and `border_radius`.
- With `dismissible: true`, the alert uses the `cp-alert` Stimulus controller
  (`data-controller="cp-alert"`), and its close button calls `cp-alert#dismiss`, which
  removes the alert. The button's accessible label is `iron_admin.alerts.dismiss`
  ("Dismiss").

**Example:**

```haml
= render IronAdmin::Ui::AlertComponent.new(
  message: "Your changes have been saved.",
  type: :success,
  dismissible: true
)

= render IronAdmin::Ui::AlertComponent.new(
  message: "Please fix the errors below.",
  type: :error
)
```

---

## ModalComponent

Dialog overlays with customizable content.

```ruby
IronAdmin::Ui::ModalComponent.new(
  size: :md,           # Optional: :sm, :md, :lg, :xl, :full
  dismissible: true    # Optional: allow closing
)
```

**Slots:**
- `title` - Modal header/title
- `footer` - Modal footer (typically action buttons)

**Example:**

```haml
= render IronAdmin::Ui::ModalComponent.new(size: :lg) do |modal|
  - modal.with_title do
    Confirm Action

  %p Are you sure you want to proceed?

  - modal.with_footer do
    = render IronAdmin::Ui::ButtonComponent.new(text: "Cancel", variant: :secondary)
    = render IronAdmin::Ui::ButtonComponent.new(text: "Confirm", variant: :primary)
```

---

## DropdownComponent

Dropdown menus with trigger and items.

```ruby
IronAdmin::Ui::DropdownComponent.new(
  align: :right,    # Optional: :left, :right
  width: 48         # Optional: width in Tailwind units (w-48)
)
```

**Slots:**
- `trigger` - The element that opens the dropdown
- `items` - Menu items (renders `ItemComponent`)

**ItemComponent options:**
- `href` - Link URL
- `method` - HTTP method
- `icon` - Heroicon name
- `destructive` - Red styling for destructive actions

**Example:**

```haml
= render IronAdmin::Ui::DropdownComponent.new(align: :right) do |dropdown|
  - dropdown.with_trigger do
    = render IronAdmin::Ui::ButtonComponent.new(text: "Actions", icon: "chevron-down")

  - dropdown.with_item(href: edit_path, icon: "pencil") do
    Edit

  - dropdown.with_item(href: delete_path, method: :delete, icon: "trash", destructive: true) do
    Delete
```

---

## TooltipComponent

Hover tooltips for additional information.

```ruby
IronAdmin::Ui::TooltipComponent.new(
  text: "Helpful info",   # Required: tooltip text
  position: :top          # Optional: :top, :bottom, :left, :right
)
```

**Example:**

```haml
= render IronAdmin::Ui::TooltipComponent.new(text: "Click to edit", position: :bottom) do
  = render IronAdmin::Ui::ButtonComponent.new(icon: "pencil", variant: :ghost)
```

---

## PaginationComponent

Pagination controls using Pagy.

```ruby
IronAdmin::Ui::PaginationComponent.new(
  pagy: @pagy    # Required: Pagy object
)
```

**Note:** Only renders when there are multiple pages.

**Note:** `@pagy` must come from the `pagy` controller method (`Pagy::Method`, Pagy 43), so
it carries the request needed to build page URLs. Page links keep the current query params.

**Example:**

```ruby
# In a controller that includes Pagy::Method
@pagy, @records = pagy(scope)
```

```haml
= render IronAdmin::Ui::PaginationComponent.new(pagy: @pagy)
```

---

## ScopesComponent

Tab-style scope navigation.

```ruby
IronAdmin::Ui::ScopesComponent.new(
  scopes: scopes,           # Required: array of scope hashes
  current_scope: "all",     # Required: currently active scope
  base_path: "/admin/users", # Required: base URL
  params: {}                # Optional: query params the tabs keep
)
```

Each tab links to `base_path` with `params` and its own `scope`. The `scope` and `page` in
`params` are dropped, so a tab starts back at the first page. Pass `iron_admin_index_state` to
keep the search, filters and sort, as the built-in index page does. It is a view helper of the
resource pages only (the views `IronAdmin::ResourcesController` renders; use
`helpers.iron_admin_index_state` in a component rendered there). On other pages, such as a tool
or the dashboard, pass the params to keep yourself, for example
`request.query_parameters.slice("q", "sort", "direction", "filters")`.

**Example:**

```ruby
scopes = [
  { name: :all, label: "All" },
  { name: :active, label: "Active" },
  { name: :archived, label: "Archived" }
]
```

```haml
-# In a view rendered by IronAdmin::ResourcesController
= render IronAdmin::Ui::ScopesComponent.new(scopes: scopes,
  current_scope: params[:scope] || "all",
  base_path: request.path,
  params: iron_admin_index_state)
```

---

## EmptyStateComponent

Placeholder for empty data states.

```ruby
IronAdmin::Ui::EmptyStateComponent.new(
  title: "No users found",       # Required: main message
  description: "Get started...", # Optional: secondary text
  icon: "users",                 # Optional: Heroicon name
  action_text: "Create User",    # Optional: action button text
  action_href: "/users/new"      # Optional: action button link
)
```

**Example:**

```haml
= render IronAdmin::Ui::EmptyStateComponent.new(
  title: "No records found",
  description: "Try adjusting your search or filters.",
  icon: "magnifying-glass"
)
```
