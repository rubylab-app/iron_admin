# Troubleshooting

Common issues and their solutions.

## Installation Issues

### "uninitialized constant IronAdmin"

**Cause:** The gem is not loaded or the engine is not properly required.

**Solutions:**
1. Ensure `gem "iron_admin"` is in your Gemfile
2. Run `bundle install`
3. Restart your Rails server

### Routes not working (404 errors)

**Cause:** Engine not mounted or mounted at wrong path.

**Solution:** Check `config/routes.rb` includes:
```ruby
mount IronAdmin::Engine => "/admin"
```

### Assets/CSS not loading (unstyled admin panel)

**Cause:** The Tailwind compiler didn't scan IronAdmin's source files.

**Solutions:**

1. Verify the import line exists in `app/assets/tailwind/application.css`:
   ```css
   @import "tailwindcss";
   @import "../builds/tailwind/iron_admin";
   ```
2. Check the bridge file exists at `app/assets/builds/tailwind/iron_admin.css`
   (run `rails tailwindcss:build` to regenerate it)
3. Verify the compiled CSS is large enough (~30KB+, not ~6KB):
   ```bash
   ls -la app/assets/builds/tailwind.css
   ```

See the [Installation guide](../getting-started/installation.md#tailwind-css-setup) for full
details on how the CSS pipeline works.

### `bin/dev` exits immediately after starting

**Cause:** This is a known upstream issue in `tailwindcss-rails` ([#602](https://github.com/rails/tailwindcss-rails/issues/602)).
The Tailwind CSS v4 binary's `--watch` flag exits when stdin is closed.
Foreman (used by `bin/dev`) does not provide a TTY to child processes, so the
watcher receives EOF on stdin and terminates. Since foreman treats any child
exit as a signal to shut down all processes, the entire `bin/dev` stack stops.

This affects **all** Rails apps using `tailwindcss-rails` v4 with foreman, not
just IronAdmin.

**Solution:** Edit `Procfile.dev` and append `[always]` to the watch task:

```diff
  web: bin/rails server
- css: bin/rails tailwindcss:watch
+ css: bin/rails tailwindcss:watch[always]
```

The `always` flag tells the Tailwind binary to keep watching even when stdin is
closed. This is the recommended workaround until the issue is resolved upstream.

## Resource Issues

### Fields not showing in forms/tables

**Cause:** Schema not loaded or field visibility restrictions.

**Solutions:**
1. Run `rails db:migrate` to ensure schema is current
2. Check field visibility settings:
   ```ruby
   field :secret, visible: false  # Hidden from all views
   ```
3. Restart Rails to reload schema

### "undefined method" errors for model attributes

**Cause:** Database column doesn't exist or model not using the expected table.

**Solutions:**
1. Verify column exists: `rails dbconsole` then `\d table_name`
2. Check model's table name matches convention
3. Run pending migrations

### Resource not appearing in sidebar

**Cause:** Resource not registered or menu configuration issue.

**Solutions:**
1. Ensure resource file exists in `app/iron_admin/resources/`
2. Check resource inherits from `IronAdmin::Resource`
3. Verify filename matches class name (`user_resource.rb` → `UserResource`)
4. For non-AR adapters (`:mongoid`, `:http`, custom): registration runs in
   two phases — `Resource.inherited` adds the class to the registry, and
   the engine's `to_prepare` block calls `ResourceRegistry.finalize!`
   after every class body has fully evaluated. If you call
   `IronAdmin::ResourceRegistry.register` manually outside the engine's
   boot path (e.g. in custom initializer), call
   `IronAdmin::ResourceRegistry.finalize!` afterwards so soft-delete
   features pick up the right adapter.

### Resources silently missing on Mongoid / HTTP / custom adapters

**Cause:** Eager registration tried to introspect the model before
`self.adapter_class = :mongoid` (or similar) had taken effect. The eager
failure is **silent by design** (no log line) — `finalize!` retries with
the correct adapter once the class body has fully evaluated. Logs only
appear if the deferred retry *also* fails.

**Solutions:**
1. Look for `[IronAdmin] Could not finalize <Resource>: <Error>` in
   `Rails.logger`. If you see one, the deferred retry failed too —
   common causes: model class doesn't exist (HTTP adapter), DB
   unreachable (transient outage at boot), or schema introspection bug
   in the adapter.
2. Confirm the registry has the resource:
   `bin/rails runner 'puts IronAdmin::ResourceRegistry.find("things")'`
3. If `find` returns `nil` and there's no `Could not finalize` log,
   `finalize!` may not have run yet (e.g. the engine's `to_prepare`
   wasn't triggered in your boot path). Run
   `IronAdmin::ResourceRegistry.finalize!` manually and re-check.

### Custom actions not appearing

**Cause:** Action not defined or policy blocking it.

**Solutions:**
1. Verify action is defined in resource:
   ```ruby
   action :my_action do |record|
     # ...
   end
   ```
2. Check policy allows the action:
   ```ruby
   policy do
     allow :my_action
   end
   ```

## Authorization Issues

### "403 Forbidden" on all pages

**Cause:** Authentication block redirecting or returning false.

**Solution:** Check `config/initializers/iron_admin.rb`:
```ruby
config.authenticate do |controller|
  # Ensure this doesn't redirect for authenticated users
  controller.redirect_to "/login" unless controller.session[:user_id]
end
```

### Fields visible to users who shouldn't see them

**Cause:** Field visibility not configured or using wrong condition.

**Solution:** Use proc-based visibility:
```ruby
field :salary, visible: ->(user) { user.admin? }
```

The proc receives the current user, not the record.

### Policy not taking effect

**Cause:** Policy not configured or wrong action names.

**Solutions:**
1. Verify policy block exists in resource
2. Use correct action names: `:read`, `:create`, `:update`, `:delete`
3. For custom actions, explicitly allow them:
   ```ruby
   policy do
     allow :read
     allow :my_custom_action  # Custom actions need explicit permission
   end
   ```

## Search Issues

### Search not finding expected records

**Cause:** Field not searchable or search syntax incorrect.

**Solutions:**
1. Check searchable fields:
   ```ruby
   searchable :name, :email  # Only these fields are searched
   ```
2. For field-specific search, use correct syntax: `email:john@example.com`

### Search showing error

**Cause:** Invalid search syntax or non-existent field.

**Solutions:**
1. Verify field exists in database
2. Check for typos in field name
3. Ensure field is visible to current user

## Export Issues

### Export returning empty file

**Cause:** No records match current filters or tenant scope.

**Solutions:**
1. Check if records exist in database
2. Verify tenant scope isn't filtering all records
3. Clear filters and try again

### Export missing fields

**Cause:** Field visibility or export_fields configuration.

**Solutions:**
1. Check `export_fields` configuration
2. Verify field visibility allows current user to see field:
   ```ruby
   field :secret, visible: ->(user) { user.admin? }
   ```

## Performance Issues

### Slow page loads (N+1 queries)

**Cause:** Association preloading not configured.

**Solution:** Add explicit preloading:
```ruby
class OrderResource < IronAdmin::Resource
  preload :customer, :line_items, :shipping_address
end
```

### Slow belongs_to dropdowns

**Cause:** Too many records being loaded.

**Solution:** Use autocomplete for large associations:
```ruby
field :customer_id, type: :belongs_to, autocomplete: true
```

Or let IronAdmin auto-switch (happens at >100 records).

## Multi-Tenant Issues

### Users seeing other tenants' data

**Cause:** Tenant scope not configured or not working.

**Solution:** Verify tenant_scope is set:
```ruby
config.tenant_scope do |scope|
  scope.where(organization_id: Current.organization.id)
end
```

Ensure `Current.organization` is set before IronAdmin loads.

### Bulk actions affecting wrong records

**Cause:** Tenant scope not applied to bulk actions.

**Solution:** IronAdmin validates all selected records are accessible. If you're seeing cross-tenant issues, check your tenant_scope configuration.

## Audit Logging Issues

### Audit logs not appearing

**Cause:** Audit not enabled or database table missing.

**Solutions:**
1. Enable auditing:
   ```ruby
   config.audit_enabled = true
   ```
2. For database storage, run migration:
   ```bash
   rails generate iron_admin:install_audit
   rails db:migrate
   ```

### Audit viewer showing empty

**Cause:** Using memory storage (default) and server restarted.

**Solution:** Use database storage for persistence:
```ruby
config.audit_storage = :database
```

## Getting Help

If you can't resolve your issue:

1. Check the [FAQ](../FAQ.md)
2. Search existing [GitHub Issues](https://github.com/rubylab-app/iron_admin/issues)
3. Open a new issue with:
   - IronAdmin version
   - Rails version
   - Ruby version
   - Error message and backtrace
   - Relevant configuration
