# Configuration Reference

All configuration options for IronAdmin.

```ruby
IronAdmin.configure do |config|
  # --- General ---
  config.title = "Admin"
  config.logo = nil
  config.per_page = 25
  config.default_sort = :created_at
  config.default_sort_direction = :desc

  # --- Multi-Tenant Support ---
  config.tenant_scope do |scope|
    scope.where(organization_id: Current.organization.id)
  end

  # --- Badge Colors ---
  config.badge_colors = {
    green: "bg-green-100 text-green-800",
    red: "bg-red-100 text-red-800",
    yellow: "bg-yellow-100 text-yellow-800",
    blue: "bg-blue-100 text-blue-800",
    indigo: "bg-indigo-100 text-indigo-800",
    purple: "bg-purple-100 text-purple-800",
    pink: "bg-pink-100 text-pink-800",
    orange: "bg-orange-100 text-orange-800",
    teal: "bg-teal-100 text-teal-800",
    gray: "bg-gray-100 text-gray-800"
  }

  # --- Authentication ---
  config.authenticate do |controller|
  end

  config.current_user do |controller|
  end

  # --- Audit Logging ---
  config.audit_enabled = true
  config.audit_storage = :memory  # or :database

  config.on_action do |event|
  end

  # --- Theme ---
  config.theme do |t|
  end

  # --- Components (a ViewComponent class or its class name; nil = built-in) ---
  config.components.table = nil
  config.components.form = nil
  config.components.filter_bar = nil
  config.components.search = nil
  config.components.navbar = nil
  config.components.sidebar = nil
  config.components.shell = nil
  config.components.fields[:type] = nil
end
```

## Configuration Options

### General

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `title` | String | `"Admin"` | Title shown in navbar |
| `logo` | String | `nil` | Path to logo image |
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

When `audit_storage: :database`, run the migration:

```bash
rails generate iron_admin:audit_migration
rails db:migrate
```

View audit logs at `/admin/audit`.

For custom audit logging, use the `on_action` callback instead.

### Badge Colors

Default color palette for badge fields. Add custom colors:

```ruby
config.badge_colors[:cyan] = "bg-cyan-100 text-cyan-800"
```

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
| `shell` | Shell around every admin page |
| `fields[:type]` | Form input for every field of that type (form only; display is unchanged) |

## Reset

```ruby
IronAdmin.reset_configuration!
```
