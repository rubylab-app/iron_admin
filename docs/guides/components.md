# Components

IronAdmin uses [ViewComponent](https://viewcomponent.org/) for all UI elements. This guide covers how to override and extend components.

For the complete component reference, see the [Components Library](../components/README.md).

## Built-in Components

### Layout Components

| Component | Purpose |
|-----------|---------|
| `IronAdmin::Layout::ShellComponent` | Main layout wrapper |
| `IronAdmin::Layout::NavbarComponent` | Top navigation bar |
| `IronAdmin::Layout::SidebarComponent` | Left sidebar navigation |
| `IronAdmin::Layout::FlashComponent` | The request's flash messages, rendered by the shell above the page content |

### UI Components

| Component | Purpose |
|-----------|---------|
| `IronAdmin::Ui::BadgeComponent` | Status badges |
| `IronAdmin::Ui::ButtonComponent` | Styled buttons |
| `IronAdmin::Ui::CardComponent` | Card containers |
| `IronAdmin::Ui::AlertComponent` | Alert boxes (success, error, warning, info), including each flash message |
| `IronAdmin::Ui::ModalComponent` | Dialog overlays |
| `IronAdmin::Ui::DropdownComponent` | Dropdown menus |
| `IronAdmin::Ui::TooltipComponent` | Hover tooltips |
| `IronAdmin::Ui::PaginationComponent` | Pagination controls |
| `IronAdmin::Ui::ScopesComponent` | Scope tabs |
| `IronAdmin::Ui::EmptyStateComponent` | Empty state placeholders |

### Form Components

| Component | Purpose |
|-----------|---------|
| `IronAdmin::Form::TextInputComponent` | Text inputs |
| `IronAdmin::Form::SelectComponent` | Select dropdowns |
| `IronAdmin::Form::CheckboxComponent` | Checkboxes |
| `IronAdmin::Form::TextareaComponent` | Multi-line text |
| `IronAdmin::Form::DatePickerComponent` | Date/time inputs |
| `IronAdmin::Form::BelongsToComponent` | Association selects |
| `IronAdmin::Form::FieldWrapperComponent` | Field wrapper with label/errors |

### Filter Components

| Component | Purpose |
|-----------|---------|
| `IronAdmin::Filters::SearchComponent` | Search input |
| `IronAdmin::Filters::SelectFilterComponent` | Dropdown filter |
| `IronAdmin::Filters::DateRangeComponent` | Date range filter |
| `IronAdmin::Filters::BarComponent` | Filter container |

### Resource Components

| Component | Purpose |
|-----------|---------|
| `IronAdmin::Resources::DataTableComponent` | Sortable data table |
| `IronAdmin::Resources::ShowFieldComponent` | Field display |
| `IronAdmin::Resources::ActionsComponent` | Record actions |
| `IronAdmin::Resources::BreadcrumbComponent` | Breadcrumb navigation |
| `IronAdmin::Resources::BulkActionsComponent` | Bulk selection actions |
| `IronAdmin::Resources::RelatedListComponent` | Has-many associations |

### Dashboard Components

| Component | Purpose |
|-----------|---------|
| `IronAdmin::Dashboards::ChartComponent` | Charts (line, bar, pie) |
| `IronAdmin::Dashboards::StatsGridComponent` | Metric stats grid |
| `IronAdmin::Dashboards::ActivityFeedComponent` | Activity timeline |
| `IronAdmin::Dashboards::QuickLinksComponent` | Quick action links |
| `IronAdmin::Dashboards::MetricCardComponent` | Single metric card |
| `IronAdmin::Dashboards::RecentTableComponent` | Recent records table |

## Flash Messages

The built-in shell renders `IronAdmin::Layout::FlashComponent` above the page content. It
shows the request's flash as `IronAdmin::Ui::AlertComponent`s, in flash order:

| Flash key | Alert type |
|-----------|------------|
| `notice`, `success` | `:success` |
| `alert`, `error` | `:error` |
| `warning` | `:warning` |
| `info` | `:info` |

Other keys, and values that are not strings (such as Devise's `timedout`), are not shown.
This covers the messages IronAdmin sets after create, update, destroy, actions, bulk actions
and imports, and the ones tools set with `ctx.flash`.

Every flash message has `role="alert"`, whatever its type. The message arrives already written
in the page Turbo renders after the redirect, and screen readers announce an inserted
`role="alert"` but not an inserted `role="status"`.

To show flash messages your own way, override the `flash` slot (see
[Overriding Components](#overriding-components)):

```ruby
config.components.flash = "AdminFlashComponent"
```

A custom shell (`config.components.shell`) replaces the built-in one, so it has to render the
`flash` slot itself, before the page body, and wrap both in a `<main>` landmark.
`iron_admin_component(:flash, ...)` builds the `flash` override, or `FlashComponent` when there
is none:

```haml
-# app/components/admin_shell_component.html.haml
%main#main-content
  = render helpers.iron_admin_component(:flash, flash: helpers.flash, current_user: @current_user)
  = content
```

`FlashComponent.new(flash: { notice: "Saved" })` renders the messages you pass instead of the
request's flash.

## Overriding Components

You can replace parts of the admin UI with your own ViewComponents. Each override fills a
**slot**. For every slot, IronAdmin renders the first of:

1. the resource's override (`component` in the resource; table, form, filter bar and search only),
2. the global override (`config.components`, or a plugin's `admin.component`),
3. the built-in component or markup.

Pages without overrides render exactly as before.

### Slots

| Slot | What it replaces | Keyword arguments IronAdmin passes | Where to set it |
|------|------------------|-----------------------------------|-----------------|
| `shell` | The page shell around every admin page. Render `content` for the page body. | `current_user` | Global |
| `navbar` | The top bar inside the built-in shell | `current_user`, `title` | Global |
| `sidebar` | The navigation inside the built-in shell | `current_user` | Global |
| `flash` | The flash messages above the page content inside the built-in shell | `flash`, `current_user` | Global |
| `table` | The records table on index pages | `records`, `fields`, `resource_class`, `current_user`, `current_sort`, `current_direction`, `scope`, `query`, `base_url` | Global or per resource |
| `form` | The form on new and edit pages | `record`, `fields`, `resource_class`, `url`, `current_user` | Global or per resource |
| `filter_bar` | The filters dropdown on index pages (only rendered when the resource has filters) | `filters`, `resource_class`, `form_url`, `scope`, `query`, `active_count`, `current_user` | Global or per resource |
| `search` | The search box on index pages (only rendered when the resource has searchable columns) | `resource_class`, `form_url`, `value`, `placeholder`, `hidden_params`, `current_user` | Global or per resource |

The same list is available in code as `IronAdmin::Configuration::Components::SLOTS`.

**The contract:**

- An override is a `ViewComponent::Base` subclass, or its class name as a String.
- IronAdmin passes only the keywords the component's `initialize` declares, or all of them
  if it takes `**options`. Declare the ones you need.
- The component must not take positional arguments, and must not require a keyword its
  slot never passes. IronAdmin raises `ArgumentError` when such a class is set. A class
  name is checked the first time IronAdmin looks it up, and an undefined name raises
  `NameError` at that point.
- `fields` and `filters` are the ones visible to the current user. The `form` slot's
  `fields` still include readonly fields; skip them with `field.readonly?(current_user)`.
  IronAdmin ignores submitted values for readonly fields either way.

**Notes per slot:**

- `shell`: a custom shell replaces the built-in shell completely, including the sidebar,
  navbar, flash messages, the `<main id="main-content">` landmark and the "Skip to content"
  link it renders. `navbar` and `sidebar` overrides only apply inside the built-in shell.
  Render the page body inside your own `<main>` landmark, and to keep the flash messages,
  render the `flash` slot before the page body (see [Flash messages](#flash-messages)).
- `flash`: `flash` is the request's flash (`ActionDispatch::Flash::FlashHash`). The component
  renders every message, so it decides which keys to show; the built-in one shows `notice`,
  `success`, `alert`, `error`, `warning` and `info` (see [Flash Messages](#flash-messages)).
  The shell renders the slot on every page, so return `false` from `render?` when there is no
  message. Give each message `role="alert"`, as the built-in one does, so screen readers
  announce it.
- `navbar` / `sidebar`: the built-in shell keeps its mobile drawer (the `cp-sidebar`
  Stimulus controller). To keep the drawer working, give your sidebar
  `data-cp-sidebar-target="panel"` and your navbar a button with
  `data-action="cp-sidebar#toggle"` and `data-cp-sidebar-target="toggle"`, as the built-in
  components do. The controller opens and closes the panel by toggling its
  `-translate-x-full` class, so give the panel that class and `lg:translate-x-0`. It treats
  the panel as a drawer while the panel is `position: fixed`, so make the panel `fixed` below
  your breakpoint and not `fixed` from it, as the built-in sidebar does with
  `fixed … lg:static`. While the panel is a drawer, the controller makes it `inert` while it
  is closed, and the rest of the shell `inert` while it is open. Opening the drawer moves
  focus to the sidebar element with `data-cp-sidebar-target="closeButton"` (or else to the
  panel's first link or button), and closing it moves focus back to the toggle.
- `table`: IronAdmin still renders the scope tabs, search, filters, bulk-action bar and
  pagination around it. Only the bulk-action bar, the table and the pagination are inside
  the `records` Turbo frame; the scope tabs, search and filters sit outside it. The frame
  has `data-turbo-action="advance"`, so a link or form inside it that does not target
  `_top` updates the address bar and the browser history. If the resource has bulk actions,
  render a checkbox per row named `ids[]` with
  `data-cp-bulk-select-target="checkbox"` and `data-action="change->cp-bulk-select#toggle"`.
  Give each one an `aria-label`, as the built-in table does with
  `iron_admin.resources.index.select_record` ("Select %{record}").
  `base_url` already includes the scope, the search query and the active filters, but never
  `sort`, `direction` or `page`, so append `sort=` and `direction=` to it. Give sort links
  `data-turbo-frame="_top"`, as the built-in table and `DataTableComponent` do: a
  whole-page visit lets the search and filter forms outside the frame pick up the new sort.
  The bundled `IronAdmin::Resources::DataTableComponent` fits this slot as is.
- `form`: submit to `url`, with the record's attributes under `record`
  (`form_with model: record, url: url, scope: :record`).
- `search`: submit `q` to `form_url` with a GET request, and add every `hidden_params`
  entry as a hidden field, so the current scope, filters and sort are kept. `hidden_params`
  carries `scope`, the active filters and, when they are set, `sort` and `direction`. Its
  keys are flat field names such as `filters[title][op]`. Render those hidden fields without
  an `id` (`hidden_field_tag name, value, id: nil`): the filter panel uses ids such as
  `filters_title_op`. Give the search input an accessible name; the built-in box and
  `IronAdmin::Filters::SearchComponent` use `aria-label` "Search <resource label>"
  (`iron_admin.resources.index.search_label`).

### Global overrides

Set global overrides in your initializer. Use class name Strings there: Rails raises
`NameError` when an initializer references a class from `app/components`, because those
classes are autoloaded after initialization.

```ruby
# config/initializers/iron_admin.rb
IronAdmin.configure do |config|
  config.components.navbar = "AdminNavbarComponent"
  config.components.sidebar = "AdminSidebarComponent"
  config.components.shell = "AdminShellComponent"
  config.components.flash = "AdminFlashComponent"
  config.components.table = "AdminTableComponent"
  config.components.form = "AdminFormComponent"
  config.components.filter_bar = "AdminFilterBarComponent"
  config.components.search = "AdminSearchComponent"
end
```

Set a slot back to `nil` to restore the built-in component.

### Per-resource overrides

A resource can override the `table`, `form`, `filter_bar` and `search` slots for its own
pages. A resource override wins over the global one.

```ruby
module IronAdmin
  module Resources
    class UserResource < IronAdmin::Resource
      component :table, UserTableComponent
      component :form, "UserFormComponent"
    end
  end
end
```

`component :navbar`, `:sidebar`, `:flash` and `:shell` raise `ArgumentError`, because those slots
apply to every page; set them in `config.components`. Any other name, such as `:index`,
`:show` or `:row`, also raises `ArgumentError` and lists the valid slots.

### Plugin overrides

Plugins set global overrides through the registration facade. This is the same as setting
`config.components.<slot>`:

```ruby
setup { |admin| admin.component :navbar, "MyPlugin::NavbarComponent" }
```

See the [plugin system design](../plugin-system-design.md) for the plugin API.

### Field input overrides

`config.components.fields[type]` replaces the form input of every field of that type, for
custom types and built-in types (for example `:email`) alike:

```ruby
IronAdmin.configure do |config|
  config.components.fields[:color_picker] = "ColorPickerInputComponent"
end
```

```ruby
class ProductResource < IronAdmin::Resource
  field :accent_color, type: :color_picker
end
```

```ruby
# app/components/color_picker_input_component.rb
class ColorPickerInputComponent < ViewComponent::Base
  def initialize(form:, field:, record:)
    @form = form
    @field = field
    @record = record
  end

  def call
    @form.color_field(@field.name, class: "h-10 w-20")
  end
end
```

The component receives `form:` (the record's form builder), `field:` (the
`IronAdmin::Field`) and `record:`. IronAdmin still renders the field's label and validation
errors around it. The label points at `form.field_id(field.name)` (`record_<field>`), so
give the input that id, as the form builder's own helpers do, or screen readers announce
it without a name. For a custom type, it takes precedence over a `form_component` or
`form_partial` registered with `FieldTypeRegistry`.

A field input override only changes the input in IronAdmin's built-in new and edit form.
It is not used in nested-form rows or inside a `form` slot override, and it does not change
how show and index pages display the value. For display, register the type with
`display` / `index_display` blocks; see
[Custom Field Types](fields.md#custom-field-types-fieldtyperegistry).

## Creating Custom Components

Custom components inherit from `ViewComponent::Base` and declare the keywords of their slot
that they use:

```ruby
# app/components/admin_navbar_component.rb
class AdminNavbarComponent < ViewComponent::Base
  def initialize(title:, current_user:)
    @title = title
    @current_user = current_user
  end

  def theme
    IronAdmin.configuration.theme
  end
end
```

```haml
-# app/components/admin_navbar_component.html.haml
%nav{ class: "#{theme.navbar_bg} p-4" }
  .flex.items-center.justify-between
    %span{ class: theme.body_text }= @title
    %span{ class: theme.muted_text }= @current_user&.name
```

## Theme Integration

Access theme properties in components via the `theme` method:

```ruby
def card_classes
  "#{theme.card_bg} #{theme.card_border} #{theme.border_radius} #{theme.card_shadow}"
end
```

## Component Documentation

For detailed documentation on each component including all options and examples:

- [UI Components](../components/ui-components.md)
- [Form Components](../components/form-components.md)
- [Filter Components](../components/filter-components.md)
- [Resource Components](../components/resource-components.md)
- [Dashboard Components](../components/dashboard-components.md)
