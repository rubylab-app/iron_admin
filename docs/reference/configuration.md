# Configuration Reference

All configuration options for IronAdmin.

```ruby
IronAdmin.configure do |config|
  # --- General ---
  config.title = "Admin"
  config.logo = nil
  config.favicon = nil # e.g. "/icon.svg"
  config.per_page = 25
  config.default_sort = :created_at
  config.default_sort_direction = :desc

  # --- Multi-Tenant Support ---
  config.tenant_scope do |scope|
    scope.where(organization_id: Current.organization.id)
  end

  # --- Badge Colors (status value => color name; add entries, don't replace the Hash) ---
  config.badge_colors["on_hold"] = "orange"

  # --- Authentication ---
  config.authenticate do |controller|
  end

  config.current_user do |controller|
  end

  # --- Audit Logging ---
  config.audit_enabled = true
  config.audit_storage = :memory  # or :database
  config.audit_user_labels { |identifiers| User.where(id: identifiers).pluck(:id, :email).to_h }

  config.on_action do |event|
  end

  # --- Themes ---
  config.theme do |t|            # the default theme (Neutral unless default_theme names another)
    t.link = "text-indigo-600 hover:text-indigo-500"
  end
  config.register_theme(:midnight, label: "Midnight") do |t|
    t.color_scheme = "dark"
  end
  config.default_theme = :neutral
  config.theme_resolver do |request| # default: the theme switcher's cookie
    request.cookies[IronAdmin::Configuration::THEME_COOKIE]
  end

  # --- Components (a ViewComponent class or its class name; nil = built-in) ---
  config.components.table = nil
  config.components.form = nil
  config.components.filter_bar = nil
  config.components.search = nil
  config.components.navbar = nil
  config.components.sidebar = nil
  config.components.shell = nil
  config.components.flash = nil
  config.components.theme_switcher = nil
  config.components.fields[:type] = nil
end
```

## Configuration Options

### General

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `title` | String | `"Admin"` | Title shown in navbar |
| `logo` | String | `nil` | Path to logo image |
| `favicon` | String | `nil` | Icon linked from every admin page with `<link rel="icon">`: a path (`"/icon.svg"`), a URL or an asset name, resolved like `logo`. With `nil`, the admin layout links no icon and browsers request `/favicon.ico` |
| `per_page` | Integer | `25` | Records per page |
| `default_sort` | Symbol | `:created_at` | Default sort column |
| `default_sort_direction` | Symbol | `:desc` | Default sort direction (`:asc` or `:desc`) |

### Multi-Tenant Support

Automatically scope all resource queries to the current tenant:

```ruby
config.tenant_scope do |scope|
  scope.where(organization_id: Current.organization.id)
end
```

The tenant scope is applied to:
- Index queries
- Show, edit, update, destroy lookups
- Export queries
- Bulk action record validation

### Audit Logging

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `audit_enabled` | Boolean | `false` | Enable built-in audit logging |
| `audit_storage` | Symbol | `:memory` | Storage backend (`:memory` or `:database`) |
| `audit_user_labels` | Block | `nil` | Labels the audit log's users: receives the user identifiers on the page, returns `{ identifier => label }`. See [User Labels](../guides/authentication.md#user-labels) |

When `audit_storage: :database`, run the migration:

```bash
rails generate iron_admin:audit_migration
rails db:migrate
```

View audit logs at `/admin/audit`.

For custom audit logging, use the `on_action` callback instead.

### Themes

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `theme` | Block | Neutral | Yields and returns the default theme, to change its properties |
| `register_theme(name, label:)` | Method with a block | none | Registers a named theme that starts from the Neutral values. With two or more themes, the navbar shows a theme switcher |
| `default_theme` | Symbol | `:neutral` | The theme used when a request resolves no registered theme |
| `theme_resolver` | Block | reads the `iron_admin_theme` cookie | Receives the request and returns the name of its theme. Unknown names and errors fall back to `default_theme` |

Read the request's theme with `IronAdmin.current_theme`. See the
[Theming guide](../guides/theming.md) and the [Theme reference](theme-properties.md).

### Badge Colors

`badge_colors` maps status values to badge color names, such as `"active" => "green"` (see
[Badge Colors](../guides/fields.md#badge-colors) for the defaults). Add or change entries;
assigning a new Hash replaces the default mapping:

```ruby
config.badge_colors["on_hold"] = "orange"
```

The classes of each color come from the theme's `badge_palette`. An entry that maps a color
name Symbol to classes sets that color's classes in every theme, and those badges have no dot:

```ruby
config.badge_colors[:cyan] = "bg-cyan-100 text-cyan-800"
```

To add a color that follows the theme, add it to the theme's `badge_palette` and
`badge_dot_palette` instead (see [Badges, alerts and chips](../guides/theming.md#badges-alerts-and-chips)).

### Components

Override global components. Each value is a `ViewComponent::Base` subclass or its class name
as a String (use a String in initializers); `nil` keeps the built-in component. A resource's
own `component` override wins over `table`, `form`, `filter_bar` and `search`. See
[Components](../guides/components.md#overriding-components) for the keyword arguments each
slot passes.

| Component | Description |
|-----------|-------------|
| `table` | Records table on index pages |
| `form` | Form on new and edit pages |
| `filter_bar` | Filters dropdown on index pages |
| `search` | Search box on index pages |
| `navbar` | Top bar inside the built-in shell |
| `sidebar` | Navigation inside the built-in shell |
| `flash` | Flash messages above the page content inside the built-in shell |
| `theme_switcher` | Theme switcher in the built-in navbar, rendered when two or more themes are registered |
| `shell` | Shell around every admin page |
| `fields[:type]` | Form input for every field of that type (form only; display is unchanged) |

## Reset

```ruby
IronAdmin.reset_configuration!
```
