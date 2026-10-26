# Authentication & Authorization

IronAdmin uses block-based authentication, compatible with any auth system.

## Authentication

### Basic Session Auth

```ruby
IronAdmin.configure do |config|
  config.authenticate do |controller|
    unless controller.session[:user_id]
      controller.redirect_to "/login"
    end
  end

  config.current_user do |controller|
    User.find_by(id: controller.session[:user_id])
  end
end
```

### Admin-Only Access

```ruby
config.authenticate do |controller|
  user = User.find_by(id: controller.session[:user_id])
  unless user&.admin?
    controller.redirect_to "/login", alert: "Access denied"
  end
end
```

### With Devise

```ruby
config.authenticate do |controller|
  unless controller.current_user&.admin?
    controller.redirect_to controller.main_app.new_user_session_path
  end
end

config.current_user do |controller|
  controller.current_user
end
```

### Multi-Environment Redirects

```ruby
config.authenticate do |controller|
  user = User.find_by(id: controller.session[:user_id])
  unless user && user.admin? && user.email_verified?
    login_url = case Rails.env
    when "production" then "https://app.example.com/login"
    when "staging" then "https://staging.example.com/login"
    else "http://localhost:3000/login"
    end
    controller.redirect_to login_url, allow_other_host: true
  end
end
```

## The `current_user` Helper

The user returned by `config.current_user` is available as `iron_admin_current_user` in all IronAdmin controllers and views.

## Policies

Per-resource access control:

```ruby
class UserResource < IronAdmin::Resource
  policy do
    allow :read, :create, :update
    deny :destroy, if: ->(user) { !user.superadmin? }
  end
end
```

### Policy Actions

| Action | Covers |
|--------|--------|
| `:read` | Index, show, CSV/JSON export, `belongs_to` autocomplete, global search results, and the sidebar link |
| `:create` | New, create, and imports (including import rows that update an existing record matched by `import_upsert_key`) |
| `:update` | Edit and update |
| `:destroy` | Destroy |

You can use either the CRUD action names (`:read`, `:create`, `:update`, `:destroy`) or the controller action names (`:index`, `:show`, `:new`, `:edit`, `:delete`). They are mapped in both directions, in `policy` and in `deny_actions`:

| Alias | CRUD action |
|-------|-------------|
| `:index`, `:show` | `:read` |
| `:new` | `:create` |
| `:edit` | `:update` |
| `:delete` | `:destroy` |

```ruby
policy do
  allow :index, :show  # Same as allow :read
  allow :create
  allow :delete        # Same as allow :destroy
end
```

Once a resource has a `policy` block, every CRUD action must be allowed explicitly. If `:read` is not allowed, the resource's index and show pages return `403`, and the resource is hidden from the sidebar and from global search. The New, Import, Edit, and Delete buttons are only shown when the policy (and `deny_actions`) allows the action.

Policy `if:` conditions run on every admin page, not only on the resource's own pages: the sidebar and global search check `:read` for every resource. Make sure each condition handles every user it can receive, including `nil` when no `current_user` block is configured.

### Conditional Policies

- `allow` with `if:` receives the **current user**
- `deny` with `if:` receives the **current user**
- Deny rules take precedence over allow rules

```ruby
policy do
  allow :read
  allow :update, if: ->(user) { user.admin? || user.manager? }
  deny :destroy, if: ->(user) { !user.superadmin? }
end
```

### Custom Action Authorization

Custom actions and bulk actions are **allowed by default**, even when a policy is defined. This separates custom action authorization from CRUD policy. To restrict a custom action, add an `allow` rule with a condition:

```ruby
class UserResource < IronAdmin::Resource
  action :lock do |record|
    record.update!(locked_at: Time.current)
  end

  bulk_action :archive do |records|
    records.update_all(archived: true)
  end

  policy do
    allow :read, :update
    allow :lock, if: ->(user) { user.admin? }      # Restrict the custom action
    allow :archive, if: ->(user) { user.admin? }    # Restrict the bulk action
  end
end
```

The show page only shows the buttons of member actions the current user may run. An action
the policy denies is hidden, and running it anyway returns `403`.

### CRUD Restrictions

For simple cases:

```ruby
class AuditLogResource < IronAdmin::Resource
  deny_actions :create, :update, :delete
end
```

`deny_actions` uses the same aliases as policies: `:delete` blocks destroy, `:new` blocks create (and imports), `:edit` blocks update, and `:index` or `:show` blocks every read of the resource, which also hides it from the sidebar and global search.

### Forbidden and Not Found Pages

When a browser request ends in `403 Forbidden` (a policy or `deny_actions` denial, or a
failing action `condition`) or `404 Not Found` (a missing or soft-deleted record, an unknown
resource, action or tool, or an import or export format the resource does not enable),
IronAdmin renders a page inside the admin layout. It shows a title, a message, and a link
back to the resource index when the user may read the resource, or to the dashboard
otherwise. Turbo form submissions also accept HTML and get the page. JSON and CSV requests,
and requests that accept only Turbo Streams, get the bare status code with an empty body.

To change the page, add your own template to the host app:

```haml
-# app/views/iron_admin/shared/error.html.haml (or error.html.erb)
%h1= error == :forbidden ? "Access denied" : "Not found"
= link_to "Dashboard", root_path
```

The template receives the local `error` (`:forbidden` or `:not_found`), and `@resource_class`
is set when the URL named a registered resource. The texts of the built-in page come from
these translation keys:

| Key | Default |
|-----|---------|
| `iron_admin.errors.forbidden.title` | "Not authorized" |
| `iron_admin.errors.forbidden.message` | "You don't have permission to view this page or perform this action." |
| `iron_admin.errors.not_found.title` | "Page not found" |
| `iron_admin.errors.not_found.message` | "This page doesn't exist, or the record was removed." |
| `iron_admin.errors.back_to_resource` | "Back to %{resource}" |
| `iron_admin.errors.back_to_dashboard` | "Back to dashboard" |

## Field-Level Authorization

Control field visibility and editability per user:

```ruby
class UserResource < IronAdmin::Resource
  field :salary, visible: ->(user) { user.admin? || user.hr? }
  field :role, readonly: ->(user) { !user.admin? }
  field :ssn, visible: ->(user) { user.admin? }
end
```

Field visibility is enforced across:
- Index table columns
- Show page fields
- Form fields
- CSV/JSON exports (`:password` values are never exported, for any user, and `:hidden` fields only when `export_fields` lists them; see [Export](export.md))
- Search queries and sorting (`:password` and `:hidden` fields are never searched or sorted on, for any user)
- Index filters (a field declared `visible: false`, `type: :password` or `type: :hidden` gets no inferred filter, and a declared filter on a field the user cannot see is neither shown nor applied)
- Dashboard recent tables

## Audit Logging

IronAdmin provides two approaches for audit logging.

### Built-in Audit Logging (Recommended)

Zero-configuration audit logging with optional database persistence:

```ruby
IronAdmin.configure do |config|
  config.audit_enabled = true
  config.audit_storage = :memory  # Default: in-memory storage
end
```

For persistent storage:

```ruby
config.audit_storage = :database
```

Then run the migration:

```bash
rails generate iron_admin:install_audit
rails db:migrate
```

View audit logs at `/admin/audit`. The page filters entries by resource, action and date. The
Action filter lists the actions logged so far, custom resource actions included.

The built-in audit log:
- Stores the last 1000 entries in memory (or unlimited in database)
- Records user, action, resource, record ID, changes, and IP address
- Logs one entry per record for create, update, destroy, member actions, bulk actions (under the
  action's name, once the block succeeds) and imports (`create` or `update` per saved row)
- Works without any database table (graceful fallback)
- Is 100% optional - no configuration required if not needed

### Custom Audit Logging

For custom audit implementations:

```ruby
config.on_action do |event|
  AuditLog.create!(
    user: event.user,
    action: event.action.to_s,
    target_type: event.resource.sub("Resource", ""),
    target_id: event.record_id,
    metadata: event.changes,
    ip_address: event.ip_address
  )
end
```

### Event Properties

| Property | Description |
|----------|-------------|
| `event.user` | Current admin user |
| `event.action` | Action performed (`:create`, `:update`, `:destroy`, or the member or bulk action name). Imports send `:create` or `:update` for each saved row |
| `event.resource` | Resource class name |
| `event.record_id` | ID of affected record |
| `event.changes` | Hash of changed attributes |
| `event.ip_address` | Client IP address |

## Multi-Tenant Support

Automatically scope all queries to the current tenant:

```ruby
IronAdmin.configure do |config|
  config.tenant_scope do |scope|
    scope.where(organization_id: Current.organization.id)
  end
end
```

The tenant scope is applied to:
- All index queries
- Record lookups (show, edit, update, destroy)
- Export queries (CSV/JSON)
- Bulk action record validation

This ensures users can only access records belonging to their tenant.
