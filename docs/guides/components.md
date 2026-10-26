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

### UI Components

| Component | Purpose |
|-----------|---------|
| `IronAdmin::Ui::BadgeComponent` | Status badges |
| `IronAdmin::Ui::ButtonComponent` | Styled buttons |
| `IronAdmin::Ui::CardComponent` | Card containers |
| `IronAdmin::Ui::AlertComponent` | Flash messages |
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

- `shell`: a custom shell replaces the built-in shell completely, including the sidebar and
  navbar it renders. `navbar` and `sidebar` overrides only apply inside the built-in shell.
- `navbar` / `sidebar`: the built-in shell keeps its mobile drawer (the `cp-sidebar`
  Stimulus controller). To keep the drawer working, give your sidebar
  `data-cp-sidebar-target="panel"` and your navbar a button with
  `data-action="cp-sidebar#toggle"`, as the built-in components do.
- `table`: IronAdmin still renders the scope tabs, search, filters, bulk-action bar and
  pagination around it, inside the `records` Turbo frame. If the resource has bulk actions,
  render a checkbox per row named `ids[]` with
  `data-cp-bulk-select-target="checkbox"` and `data-action="change->cp-bulk-select#toggle"`.
  `base_url` already includes the scope and search query, so append `sort=` and
  `direction=` to it. The bundled `IronAdmin::Resources::DataTableComponent` fits this slot
  as is.
- `form`: submit to `url`, with the record's attributes under `record`
  (`form_with model: record, url: url, scope: :record`).
- `search`: submit `q` to `form_url` with a GET request, and add `hidden_params` as hidden
  fields so the current scope and filters are kept.

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

`component :navbar`, `:sidebar` and `:shell` raise `ArgumentError`, because those slots
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
errors around it. For a custom type, it takes precedence over a `form_component` or
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
    %h1{ class: theme.body_text }= @title
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
