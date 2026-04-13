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
    deny :delete, if: ->(record) { record.admin? }
  end
end
```

### Policy Actions

| Action | Covers |
|--------|--------|
| `:read` | Index and show |
| `:create` | New and create |
| `:update` | Edit and update |
| `:delete` | Destroy |

You can use either the CRUD action names (`:read`, `:create`, `:update`, `:delete`) or the controller action names (`:index`, `:show`, `:new`, `:edit`, `:destroy`). They are automatically mapped:

```ruby
policy do
  allow :index, :show  # Same as allow :read
  allow :create
end
```

### Conditional Policies

- `allow` with `if:` receives the **current user**
- `deny` with `if:` receives the **record**

```ruby
policy do
  allow :read
  allow :update, if: ->(user) { user.admin? || user.manager? }
  deny :delete, if: ->(record) { record.protected? }
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

### CRUD Restrictions

For simple cases:

```ruby
class AuditLogResource < IronAdmin::Resource
  deny_actions :create, :update, :delete
end
```

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
- CSV/JSON exports
- Search queries

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
rails generate iron_admin:audit_migration
rails db:migrate
```

View audit logs at `/admin/audit`.

The built-in audit log:
- Stores the last 1000 entries in memory (or unlimited in database)
- Records user, action, resource, record ID, changes, and IP address
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
| `event.action` | Action performed (`:create`, `:update`, `:destroy`, or custom action name) |
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
