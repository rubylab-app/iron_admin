# Frequently Asked Questions

## General

### What is IronAdmin?

IronAdmin is a convention-over-configuration admin panel engine for Ruby on Rails. It automatically generates admin interfaces from your database schema with minimal configuration.

### What are the requirements?

- Ruby >= 3.3
- Rails >= 8.0.4
- [tailwindcss-rails](https://github.com/rails/tailwindcss-rails) >= 4.3 (Tailwind CSS v4, for default styling)
- The default `rails new` JavaScript setup (importmap with Stimulus). IronAdmin installs `importmap-rails` itself and registers its Stimulus controllers on `window.Stimulus`, which `bin/rails stimulus:install` sets up.

See [UPGRADING.md](../UPGRADING.md) when moving from an older release.

### Is IronAdmin production-ready?

Yes. IronAdmin is designed for production use with comprehensive test coverage (95%+), security features (field visibility, tenant scoping, authorization), and performance optimizations (association preloading, caching).

## Installation

### How do I install IronAdmin?

```bash
bundle add iron_admin
rails generate iron_admin:install
```

### Why aren't my Tailwind styles working?

IronAdmin ships no compiled CSS. Your app's Tailwind v4 build has to scan the engine's views and components, through the bridge file that `tailwindcss-rails` (>= 4.3) generates. Make sure `app/assets/tailwind/application.css` contains:

```css
@import "tailwindcss";
@import "../builds/tailwind/iron_admin";
```

Then run `bin/rails tailwindcss:build` and check that `app/assets/builds/tailwind/iron_admin.css` exists. Run the build again after every `bundle update iron_admin`, because the bridge file points at the installed gem's path. See [Tailwind CSS Setup](getting-started/installation.md#tailwind-css-setup) for details.

### How do I change the admin path from /admin?

In `config/routes.rb`:

```ruby
mount IronAdmin::Engine => "/dashboard"  # or any path
```

## Resources

### Why aren't my model fields showing?

IronAdmin infers fields from your database schema. Ensure:
1. The model's table exists in the database
2. You've run migrations
3. The resource is registered (check `app/iron_admin/`)

### How do I hide a field?

```ruby
class UserResource < IronAdmin::Resource
  field :password_digest, visible: false
  field :secret, visible: ->(user) { user.admin? }
end
```

### How do I make a field read-only?

```ruby
class UserResource < IronAdmin::Resource
  field :email, readonly: true
  field :role, readonly: ->(user) { !user.admin? }
end
```

Readonly fields are left out of the form and are never mass-assigned on create or update, even when a request submits a value for them.

### How do I customize field display in the index table?

```ruby
class UserResource < IronAdmin::Resource
  index_fields :id, :name, :email, :role, :created_at
end
```

### How do I create a custom action?

```ruby
class UserResource < IronAdmin::Resource
  action :lock, icon: "lock-closed", confirm: true do |record|
    record.update!(locked_at: Time.current)
  end
end
```

## Authorization

### How do I restrict access to certain users?

Configure authentication in the initializer:

```ruby
IronAdmin.configure do |config|
  config.authenticate do |controller|
    unless controller.current_user&.admin?
      controller.redirect_to "/login"
    end
  end
end
```

### How do I restrict CRUD actions per resource?

Use policies:

```ruby
class UserResource < IronAdmin::Resource
  policy do
    allow :read
    allow :update, if: ->(user) { user.admin? }
    deny :delete
  end
end
```

Once a resource has a `policy` block, every CRUD action must be allowed explicitly. A policy that does not allow `:read` returns `403` on the index and show pages and hides the resource from the sidebar and global search. `:new`, `:edit`, and `:delete` are aliases for `:create`, `:update`, and `:destroy`, so `deny :delete` blocks destroy.

Or use `deny_actions` for simple cases:

```ruby
class AuditLogResource < IronAdmin::Resource
  deny_actions :create, :update, :delete
end
```

`deny_actions` uses the same aliases: `:delete` blocks destroy, and `:index` or `:show` blocks every read of the resource.

### How do I hide fields from certain users?

```ruby
field :salary, visible: ->(user) { user.admin? || user.hr? }
```

## Multi-Tenant

### How do I scope data to the current tenant?

```ruby
IronAdmin.configure do |config|
  config.tenant_scope do |scope|
    scope.where(organization_id: Current.organization.id)
  end
end
```

## Search

### How do I search a specific field?

Use the format `field:value` in the search box:

```
email:john@example.com
name:John
created_at:2025-01-01..2025-12-31
```

### How do I customize which fields are searchable?

```ruby
class UserResource < IronAdmin::Resource
  searchable :name, :email
end
```

## Export

### How do I export data?

CSV and JSON exports are enabled by default. Access via:
- `/admin/users/export?format=csv`
- `/admin/users/export?format=json`

### How do I customize export fields?

```ruby
class UserResource < IronAdmin::Resource
  export_fields :id, :name, :email, :created_at
end
```

### How do I disable export?

```ruby
class SecretResource < IronAdmin::Resource
  exports  # Empty to disable
end
```

## Dashboard

### How do I create a custom dashboard?

```ruby
class AdminDashboard < IronAdmin::Dashboard
  metric :total_users, format: :number do
    User.count
  end

  recent :users, limit: 5
end
```

### How do I add charts?

```ruby
class AdminDashboard < IronAdmin::Dashboard
  chart :signups_by_month, type: :bar do
    User.group_by_month(:created_at).count
  end
end
```

## Performance

### How do I prevent N+1 queries?

IronAdmin automatically preloads `belongs_to` associations. For custom preloading:

```ruby
class OrderResource < IronAdmin::Resource
  preload :customer, :line_items
end
```

### Why is my belongs_to dropdown slow?

For associations with many records (>100), IronAdmin automatically switches to an autocomplete component. You can force autocomplete:

```ruby
field :customer_id, type: :belongs_to, autocomplete: true
```

## Audit Logging

### How do I enable audit logging?

```ruby
IronAdmin.configure do |config|
  config.audit_enabled = true
end
```

### How do I persist audit logs to the database?

```ruby
config.audit_storage = :database
```

Then run:

```bash
rails generate iron_admin:install_audit
rails db:migrate
```

View logs at `/admin/audit`.
