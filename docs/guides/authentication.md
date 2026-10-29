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

Devise defines `current_user` on every controller. A helper that exists only on the host application's `ApplicationController` is not available in the block: IronAdmin controllers inherit from `ActionController::Base`, not from that class, so calling it raises `NoMethodError` on every admin request. `controller.cookies` is private; read cookies with `controller.request.cookie_jar`. The `unless` above redirects a signed-out visitor, because `nil` is not an admin. Making `current_user&.admin?` itself the block's value would let that visitor in: add `|| false`, since `nil` allows the request.

### With the Rails 8 authentication generator

```ruby
config.authenticate do |controller|
  # || false: a signed-out visitor makes &.admin? nil, and nil allows the request.
  Session.find_by(id: controller.request.cookie_jar.signed[:session_id])&.user&.admin? || false
end

config.current_user do |controller|
  Session.find_by(id: controller.request.cookie_jar.signed[:session_id])&.user
end
```

`Current.user` is not set in IronAdmin requests, because the host's `Authentication` concern does not run there.

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

### Block value

Redirect or render inside the block to choose the response. To deny the request with `403`, make `false` the block's last value. HTML gets the error page without the admin shell, and any other format gets a bare `403`. `nil`, `true` and any other value allow the request. A block that already redirected or rendered keeps that response, whatever its value is.

Do not use `return` inside the block. The block runs from the controller, and `return` leaves the method that defined the block, which in an initializer raises `LocalJumpError`. To stop early, use `next false`.

A block that ends with `redirect_to ... unless ...` has the value `nil` when it does not redirect, so the request continues. The initializer from `rails generate iron_admin:install` leaves the block body commented out, which also has the value `nil`.

```ruby
config.authenticate do |controller|
  # || false: a signed-out visitor makes &.admin? nil, and nil allows the request.
  User.find_by(id: controller.session[:user_id])&.admin? || false
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

Policy `if:` conditions run on every admin page, not only on the resource's own pages: the sidebar and global search check `:read` for every resource. Make sure each condition handles every user it can receive, including `nil` when no `current_user` block is configured. In an `allow ... if:` rule, a proc that returns `nil` does not allow the action, so `nil` denies there. In a `deny ... if:` rule, `nil` means the deny does not apply. In `config.authenticate`, `nil` allows the request.

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

A policy denial, a `deny_actions` denial, a failing action `condition`, or a `404 Not Found`
(a missing or soft-deleted record, an unknown resource, action or tool, or an import or export
format the resource does not enable) renders a page inside the admin layout. It shows a title,
a message, and a link back to the resource index when the user may read the resource, or to the
dashboard otherwise. Turbo form submissions also accept HTML and get the page. JSON and CSV
requests, and requests that accept only Turbo Streams, get the bare status code with an empty
body. On these pages `@resource_class` is set when the URL named a registered resource.

An `authenticate` block whose value is `false` uses the same error template and the same bare
status for other formats, but not the admin layout. HTML gets `layouts/iron_admin/minimal`:
the document head, the stylesheets and the theme classes, without the sidebar, the navbar, the
search or the theme switcher, and without a link back into the admin. `@resource_class` is not
set, because the block runs before the controller looks up the resource. The shell is left out
on purpose. It checks `:read` for every resource, and a condition such as
`->(user) { user.admin? }` raises `NoMethodError` for a signed-out visitor, which would turn
the 403 into a 500. A host can replace that layout with `app/views/layouts/iron_admin/minimal.html.haml`.

To change the page, add your own template to the host app:

```haml
-# app/views/iron_admin/shared/error.html.haml (or error.html.erb)
%h1= error == :forbidden ? "Access denied" : "Not found"
- if iron_admin_error_navigation?
  = link_to "Dashboard", root_path
```

The template receives only the local `error` (`:forbidden` or `:not_found`).
`iron_admin_error_navigation?` is true for policy denials and 404s, and false when an
`authenticate` block denies the request. Keep any link into the admin, and any call that runs
a policy, behind that helper: the built-in template does. A host template that declares strict
locals for `error` only still renders. The texts of the built-in page come from
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

#### User Labels

Database storage keeps each user as an identifier, the user's id as a string, so by default
the User column shows ids such as `1`. (Memory storage keeps the user object and shows its
`email` or `name`.) To show a label instead, with either storage, configure `audit_user_labels`:

```ruby
IronAdmin.configure do |config|
  config.audit_user_labels do |identifiers|
    User.where(id: identifiers).pluck(:id, :email).to_h
  end
end
```

The block receives the distinct identifiers of every entry on the page and is called once per
page, so a single query labels all of them. It returns a hash of labels keyed by identifier
(string or integer keys). With memory storage, a label from the block replaces the user's
`email` or `name`. A user missing from the hash, such as a deleted user, and a blank label keep
the default: the identifier with database storage, the `email` or `name` with memory storage.
If the block raises, the error is logged as `[IronAdmin] ...` and the page shows those
defaults, so the audit log stays readable. An entry logged without a user shows "Unknown".

The built-in audit log:
- Stores the last 1000 entries in memory (or unlimited in database)
- Records user, action, resource, record ID, changes, and IP address
- Logs one entry per record for create, update, destroy, member actions, bulk actions (under the
  action's name) and imports (`create` or `update` per saved row), once the change commits. An
  action that returns `false` or raises, and an import that rolls back, log nothing
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
