# Upgrading to IronAdmin 0.7.0 (Ruby 3.3+ / Rails 8.0.4+)

Version 0.7.0 raises the minimum Ruby and Rails versions and declares dependency floors that match the APIs IronAdmin actually uses. It also closes several authorization and data-handling gaps, and makes component overrides take effect. The resource, dashboard, tool and policy DSLs keep their methods, but some requests that used to succeed now return `403` or `404`, and some markup changed. Read every section before upgrading.

## What changed

### 1. Ruby >= 3.3 is required

Ruby 3.2 is end of life. IronAdmin 0.7.0 declares `required_ruby_version >= 3.3` and is tested on Ruby 3.3, 3.4, and 4.0.

`csv` and `ostruct` are now runtime dependencies of IronAdmin. They are no longer default gems (`csv` since Ruby 3.4, `ostruct` since Ruby 4.0), and 0.6.0 failed to load on Ruby 3.4 under Bundler with `cannot load such file -- csv`.

**Action required:** Upgrade your application to Ruby 3.3 or newer before you run `bundle update iron_admin`. On Ruby 3.2, Bundler will not resolve 0.7.0. If you added `gem "csv"` or `gem "ostruct"` to your Gemfile only for IronAdmin, you can remove those lines.

### 2. Rails >= 8.0.4 is required

Rails 7.1 and 7.2 are no longer supported. IronAdmin 0.7.0 declares `rails >= 8.0.4` and is tested on Rails 8.0 and 8.1. The floor is 8.0.4 rather than 8.0.0 because 8.0.0 to 8.0.3 have an integration-test bug that IronAdmin's suite hits: requests made with `as: :html` raise `NoMethodError: undefined method 'to_html' for an instance of Hash`.

On Rails 8.0, keep the `json` gem below 3.0 (`gem "json", "< 3"`). Active Support 8.0 passes `quirks_mode:` to JSON, which json 3.0 rejects with an `ArgumentError`. Rails 8.1 is not affected.

**Action required:** Upgrade to Rails 8.0.4 or newer first ([Rails upgrade guide](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html)), then update IronAdmin. Rails 8.0 reaches end of life on 2026-11-07, so we recommend going straight to Rails 8.1.

### 3. Dependency floors match what IronAdmin uses

Earlier gemspecs declared floors below the APIs IronAdmin calls. For example, they said `pagy >= 6.0`, but IronAdmin has always used Pagy 43's `Pagy::Method`, so Pagy 6 to 9 failed with `uninitialized constant Pagy::Method`. 0.7.0 declares the real minimums:

| Gem | 0.6.0 | 0.7.0 | Why |
|-----|-------|-------|-----|
| `rails` | `>= 7.1` | `>= 8.0.4` | See section 2 |
| `pagy` | `>= 6.0` | `>= 43.7.1, < 44` | Pagy 43 API; 43.7.1 is the first release that renders malformed or huge `page` params (`0`, `abc`, `page[]=1`, `2**63`) instead of raising a `500` |
| `view_component` | `>= 3.0` | `>= 4.0, < 5` | No 3.x release works on Rails 8 |
| `turbo-rails` | `>= 2.0` | `>= 2.0.6` | 2.0.0 to 2.0.5 crash at eager-load boot when Action Cable is not loaded |
| `importmap-rails` | not declared | `>= 2.0` | The admin layout calls `javascript_importmap_tags` |
| `csv` | not declared | `>= 3.2.8` | See section 1 |
| `ostruct` | not declared | `>= 0.6` | See section 1 |
| `stimulus-rails` | `>= 1.3` | `>= 1.3` | Unchanged |
| `haml-rails` | `>= 2.0` | `>= 2.0` | Unchanged |
| `heroicon` | `>= 1.0` | `>= 1.0` | Unchanged |

**Action required:** If `bundle update iron_admin` fails to resolve, your Gemfile or lockfile pins one of these gems below the new floor (or, for Pagy and ViewComponent, above the new upper bound). Upgrade that gem. Pagy versions below 43 never worked with IronAdmin; the other floors are the oldest versions 0.7.0 is tested against. If your own code uses the pre-43 Pagy API (`Pagy::Backend`, `Pagy::Frontend`), follow Pagy's upgrade guide for version 43.

### 4. Host app setup: importmap with Stimulus, and tailwindcss-rails >= 4.3

The admin layout loads its JavaScript with `javascript_importmap_tags` and registers its Stimulus controllers on `window.Stimulus`. In 0.6.0, a host without importmap-rails got a `NameError` on every admin page. IronAdmin now declares and requires `importmap-rails` itself, but the host still needs the default `rails new` JavaScript setup: an importmap `application` entry point that starts Stimulus and sets `window.Stimulus`, which `bin/rails stimulus:install` generates.

IronAdmin ships no compiled CSS. Your Tailwind v4 build scans the engine through the bridge file `app/assets/builds/tailwind/iron_admin.css`, and only tailwindcss-rails 4.3 and later generate it (the `tailwindcss:engines` task). With 4.0 to 4.2, the bridge file is never written and the admin panel renders unstyled.

**Action required:**

- Use `tailwindcss-rails` 4.3 or newer.
- Rebuild your CSS after upgrading (`bin/rails tailwindcss:build`). The bridge file points at the installed gem's path, and 0.7.0's new classes (responsive layout, Tailwind v4 opacity modifiers) only appear in a fresh build. If you commit `app/assets/builds/tailwind.css`, commit the rebuilt file too.
- If you pin `importmap-rails` below 2.0, upgrade it.

### 5. `:read` now gates the index, export, autocomplete, search, and sidebar

Until 0.6.0, the `:read` permission from `policy` or `deny_actions` was only checked on the show page. It now also applies to:

- the index page (`403`)
- CSV/JSON export (`403`)
- `belongs_to` autocomplete against that resource (`403`)
- global search (the resource is left out of the results)
- the sidebar (the link is hidden)

Once a resource has a `policy` block, every CRUD action must be allowed explicitly. In 0.6.0, a policy that never allowed `:read` still left the index page reachable. In 0.7.0 it returns `403` and the resource disappears from the sidebar.

**Action required:** Make sure every policy whose index page should stay visible allows `:read`:

```ruby
# Before (index page worked, show page returned 403)
policy do
  allow :create, :update
end

# After
policy do
  allow :read, :create, :update
end
```

Also check forms on other resources. A `belongs_to` field that autocompletes against a resource the current user cannot read now gets `403` from the autocomplete endpoint.

Imports now check the `:create` policy as well as `deny_actions`, so `deny :create` also blocks imports.

The New and Import buttons on the index page and the Edit and Delete buttons on the show page now follow the resource policy, not only `deny_actions`. A user whose policy denies `:create`, `:update` or `:destroy` no longer sees those buttons. Update system specs that expect them for such users.

Policy `if:` conditions now also run outside the resource's own pages. On every admin page, the sidebar checks `:read` for every resource. Global search checks `:read`. The index and show pages check `:create`, `:update`, and `:destroy` to decide which buttons to show. Make sure conditions handle every user they can receive, including `nil` when no `current_user` block is configured. A condition such as `->(user) { user.admin? }` that raises now breaks every admin page, not only that resource's pages.

> **Note:** Resource policies do not filter dashboard widgets or live-update streams. If a dashboard shows data from a restricted resource, restrict that widget yourself.

### 6. `:new`, `:edit`, and `:delete` are aliases in policies and `deny_actions`

In policies, `:new`, `:edit`, and `:delete` now map to `:create`, `:update`, and `:destroy`, the same way `:index` and `:show` already mapped to `:read`. `deny_actions` did no alias mapping at all in 0.6.0. It now maps all five names: `:index`/`:show` → `:read`, `:new` → `:create`, `:edit` → `:update`, `:delete` → `:destroy`. This can **grant** access as well as revoke it:

| Rule | 0.6.0 | 0.7.0 |
|------|-------|-------|
| `allow :delete` | destroy still forbidden | destroy allowed |
| `allow :edit` / `allow :new` | update / create still forbidden | update / create allowed |
| `deny :delete` | no effect on destroy | destroy denied |
| `deny_actions :delete` | no effect (destroy still worked) | destroy blocked |
| `deny_actions :index` / `deny_actions :show` | no effect | every read blocked: index, show, export, autocomplete and search, and the sidebar link is hidden |
| `deny_actions :new` / `deny_actions :edit` | no effect | create (including imports) / update blocked |

A condition that fails on one alias no longer hides a matching rule on another alias.

**Action required:** Review every `policy` that uses `:new`, `:edit`, or `:delete`, and every `deny_actions` that uses `:index`, `:show`, `:new`, `:edit`, or `:delete`. In particular:

- `allow :read, :create, :update, :delete` now lets users delete records.
- `deny_actions :create, :update, :delete`, the read-only example in the 0.6.0 docs, now also blocks destroy.
- `deny_actions :show` now hides the whole resource.

### 7. Readonly fields are no longer mass-assignable

Fields declared with `readonly: true`, or with a `readonly:` proc that returns true for the current user, are removed from the permitted params on create and update. This includes direct `POST`/`PATCH` requests. The admin forms already left these fields out, so the UI behaves the same.

**Action required:** If an API client, a custom form, or a request spec submits a readonly attribute and expects it to be saved, set the value another way (for example a model default or callback). Alternatively, make the `readonly:` proc return false for the users who may change it.

### 8. Soft-deleted records: only show, destroy, and restore can reach them

For models whose default scope hides soft-deleted rows (for example `default_scope { where(deleted_at: nil) }`, as paranoia sets up), a soft-deleted record now returns `404` from edit, update, and every custom member action and its action form, except `restore`. Show, destroy, and `restore` still find it. IronAdmin does not filter `deleted_at` itself, so models with a `deleted_at` column but no such default scope are unaffected.

For those models, the show page no longer renders an Edit button for a soft-deleted record.

**Action required:** Restore a record before editing it. If a custom action has to work on soft-deleted rows, run it after `restore`.

### 9. Malformed JSON fields re-render the form

When a `:json` field contains invalid JSON, create and update now re-render the form with status `422 Unprocessable Content` and the error "Invalid JSON. The record was not saved.", and nothing is saved. In 0.6.0 the JSON field was dropped and the other attributes were saved.

**Action required:** Update request or system specs that expect a redirect after submitting malformed JSON.

### 10. Tool URLs only call methods defined on the tool class

For an action without a `tool_action` declaration, `POST /admin/tools/:tool/:action` now only dispatches to public methods defined directly in that tool class. Methods inherited from a parent class or included from a module return `404`.

**Action required:** Declare shared actions with `tool_action`. Declarations are inherited, so declaring the action once on the base class covers every subclass. Declared actions also get a button on the default tool page.

```ruby
# Before: /admin/tools/reports/refresh ran the inherited method
class BaseTool < IronAdmin::Tool
  def refresh; end
end

class ReportsTool < BaseTool
end

# After: declare it (once on the base class is enough)
class BaseTool < IronAdmin::Tool
  tool_action :refresh

  def refresh; end
end
```

### 11. Unexpected errors show a generic message

When a custom action, bulk action, or import raises an unexpected exception, admins now see "Something went wrong. Please try again." (`iron_admin.errors.unexpected`) instead of the exception message. The exception is logged as `[IronAdmin] <class>: <message>`. Import validation errors (`ArgumentError`) still show their message.

**Action required:** If you customized the `iron_admin.resources.action.failure` or `iron_admin.resources.bulk_action.failure` translations, move the text to `iron_admin.errors.unexpected`; the old keys are no longer used. Specs that assert on the exception text in the flash need updating. Action blocks that raise on purpose to show a message to admins will now show the generic text.

### 12. CSV exports neutralize formula-like cells

CSV cells whose text starts with `=`, `+`, `-`, `@`, a tab, or a carriage return get a leading `'` so spreadsheet apps do not evaluate them. This includes negative numbers: `-5` is exported as `'-5`. JSON export is unchanged.

**Action required:** If another system parses IronAdmin CSV exports, strip a leading `'` or switch it to the JSON export.

### 13. Search and display changes

- Global search only matches searchable columns that are visible to the current user.
- Index search `field:from..to` on a datetime column now includes the whole `to` day.
- `:rich_text` values are passed through Rails' `sanitize`. Markup outside Rails' default allowlist (for example `<iframe>`, `<script>`, or `style` attributes) is stripped.
- On show pages, a polymorphic `belongs_to` whose stored type is not in the field's allowed types (declared with `types:`, or inferred from `has_many`/`has_one ... as:`) is shown as plain `Type#id` text instead of a link.
- HTTP adapter: a record id that is empty or contains `/`, `\`, or `..` raises `IronAdmin::RecordNotFound` (`404`). Other ids are URL-escaped with `CGI.escape` before they go into the request path.

### 14. Layout markup changed (responsive UI)

- Page containers use `p-4 sm:p-6 lg:p-8` instead of `p-8` on the dashboard and on index, show, new, edit, import, audit, search, tool, and action-form pages. The bulk-action form still uses `p-8`.
- Below the `lg` breakpoint (1024px), the sidebar is an off-canvas drawer, opened with the "Open menu" button in the navbar.
- Wide tables are wrapped in `overflow-x-auto`, and show-page detail rows stack vertically below `sm`.
- Overlays use Tailwind v4 opacity modifiers (`bg-gray-900/50`, `bg-gray-500/75`) instead of `bg-opacity-*`, which Tailwind v4 removed. On Tailwind v4 the modal overlay rendered solid gray; it is translucent now.
- With haml 6 or later, index rows and dashboard metric cards no longer render an empty `id=""` when live updates are off.

**Action required:** Update host CSS or system specs that select `.p-8` or assume the sidebar is always visible. Run browser system specs with a window at least 1024px wide (Rails' default `screen_size: [1400, 1400]` is fine), or click "Open menu" before using sidebar links.

### 15. Component overrides now take effect

In 0.6.0, `config.components` and `Resource.component` stored overrides that nothing rendered. In 0.7.0 they are used: `config.components.shell`, `navbar`, `sidebar`, `table`, `form`, `filter_bar`, `search` and `fields[type]` change what renders, and a resource's `component :table`, `:form`, `:filter_bar` or `:search` wins over the global one for that resource. Slot overrides are checked when they are set (a `fields[type]` entry, and any class name String, is checked when it is first rendered):

- An override that is not a `ViewComponent::Base` subclass (or its class name), takes a positional argument, or requires a keyword its slot never passes raises `ArgumentError`.
- `Resource.component` raises `ArgumentError` for any slot other than `:table`, `:form`, `:filter_bar` and `:search`. That includes `:index`, `:show` and `:row`, which only an old code comment mentioned and which never did anything, and the global-only `:navbar`, `:sidebar` and `:shell`.

**Action required:** If your app sets any component override, check that the component renders what you expect, and that its `initialize` only requires keywords its slot passes (see [Components](docs/guides/components.md#overriding-components)). Remove `component :index`, `:show` or `:row` from resources; they raise at boot now. In initializers, set overrides as class name Strings (`config.components.navbar = "AdminNavbarComponent"`), because Rails raises `NameError` when an initializer references a class from `app/components`.

### 16. `Adapters::Base#pagy_method` is deprecated

`pagy_method` and the built-in implementations are unused: pagination always uses Pagy's default `:offset` paginator, which works with any scope that responds to `count`, `offset`, and `limit`. Pagy 43 has no `pagy_mongoid` backend. The method will be removed in 0.8.0.

**Action required:** None. Custom adapters can keep returning `:pagy` until 0.8.0.

## What does NOT change

- **Resource, dashboard, tool, and policy DSL** — No DSL method was removed or renamed. `Resource.component` now validates its slot (section 15).
- **Configuration** — `IronAdmin.configure` blocks work as before. Component overrides are now validated and rendered (section 15).
- **Routes and URLs** — Unchanged.
- **Database** — No new migrations. `rails generate iron_admin:install_audit` now stamps newly generated migrations with your Rails version (for example `ActiveRecord::Migration[8.1]`) instead of `[7.1]`; existing migrations need no change.

---

# Upgrading to IronAdmin 0.6.0 (Adapter-Agnostic)

Version 0.6.0 makes IronAdmin adapter-agnostic and adds Mongoid (MongoDB) and HTTP REST API support. Most applications require no changes, but there are a few breaking changes if you interact with IronAdmin internals.

## What changed

### 1. Exception types

Controllers now raise `IronAdmin::RecordNotFound` instead of `ActiveRecord::RecordNotFound`.

**Action required:** If your application rescues `ActiveRecord::RecordNotFound` in middleware or custom code that wraps IronAdmin routes, update it:

```ruby
# Before
rescue ActiveRecord::RecordNotFound
  render_404

# After
rescue IronAdmin::RecordNotFound
  render_404
```

### 2. adapter_class default is now a symbol

`Resource.adapter_class` defaults to `:active_record` instead of `IronAdmin::Adapters::ActiveRecord`.

**Action required:** If your tests assert on `adapter_class`:

```ruby
# Before
expect(MyResource.adapter_class).to eq(IronAdmin::Adapters::ActiveRecord)

# After
expect(MyResource.adapter_class).to eq(:active_record)
```

### 3. QueryBuilder renamed

`IronAdmin::Filters::QueryBuilder` is now `IronAdmin::Filters::ActiveRecordQueryBuilder`. The old name is preserved as an alias, but if you subclass `QueryBuilder`, update to inherit from `ActiveRecordQueryBuilder` (or `BaseQueryBuilder` for adapter-agnostic filters).

### 4. New abstract methods on Adapters::Base

If you have a custom adapter (not using the built-in `:active_record` or `:mongoid`), implement these new methods:

| Method | Purpose |
|--------|---------|
| `record_changes(record)` | Returns changes hash after save (AR: `saved_changes`, Mongoid: `previous_changes`) |
| `wrap_rollback(&block)` | Wraps block converting `IronAdmin::Rollback` to adapter-native rollback |
| `query_builder_class` | Returns the QueryBuilder class for operator filters |
| `pagy_method` | Deprecated in 0.7.0 and unused by IronAdmin (pagination always uses Pagy's `:offset` paginator); return `:pagy`. Removed in 0.8.0. |
| `cast_boolean(value)` | Casts string to boolean |

### 5. Using Mongoid

To use IronAdmin with MongoDB, add `mongoid` to your Gemfile and configure resources:

```ruby
class ArticleResource < IronAdmin::Resource
  self.adapter_class = :mongoid
end
```

The Mongoid adapter is only loaded when `:mongoid` is configured — it adds zero overhead to ActiveRecord-only apps.

## What does NOT change

- **Routes, URLs, views** — No changes needed.
- **Resource DSL** — All DSL methods work identically.
- **Configuration** — `IronAdmin.configure` blocks unchanged.
- **Existing ActiveRecord apps** — Zero changes required for apps not using Mongoid.

---

# Upgrading to IronAdmin 0.5.0

## Namespaced Resources and Dashboards

Version 0.5.0 introduces namespaced directory structure for resources and dashboards. Resource classes now live under `IronAdmin::Resources` and dashboard classes under `IronAdmin::Dashboards`. This prevents namespace pollution in host applications and provides better organization.

### Directory structure changes

**Before (0.4.x):**

```
app/iron_admin/
  user_resource.rb
  product_resource.rb
  admin_dashboard.rb
```

**After (0.5.0):**

```
app/iron_admin/
  resources/
    user_resource.rb
    product_resource.rb
  dashboards/
    admin_dashboard.rb
```

### Step-by-step migration

#### 1. Create the new directories

```bash
mkdir -p app/iron_admin/resources
mkdir -p app/iron_admin/dashboards
```

#### 2. Move resource files

Move all `*_resource.rb` files into `app/iron_admin/resources/`:

```bash
mv app/iron_admin/*_resource.rb app/iron_admin/resources/
```

#### 3. Move dashboard files

Move all `*_dashboard.rb` files into `app/iron_admin/dashboards/`:

```bash
mv app/iron_admin/*_dashboard.rb app/iron_admin/dashboards/
```

#### 4. Update resource class definitions

Wrap each resource class in the `IronAdmin::Resources` module:

```ruby
# Before (app/iron_admin/user_resource.rb)
class UserResource < IronAdmin::Resource
  # ...
end

# After (app/iron_admin/resources/user_resource.rb)
module IronAdmin
  module Resources
    class UserResource < IronAdmin::Resource
      # ...
    end
  end
end
```

#### 5. Update dashboard class definitions

Wrap each dashboard class in the `IronAdmin::Dashboards` module:

```ruby
# Before (app/iron_admin/admin_dashboard.rb)
class AdminDashboard < IronAdmin::Dashboard
  # ...
end

# After (app/iron_admin/dashboards/admin_dashboard.rb)
module IronAdmin
  module Dashboards
    class AdminDashboard < IronAdmin::Dashboard
      # ...
    end
  end
end
```

#### 6. Update any direct class references

If your application code references resource or dashboard classes directly, update the references:

```ruby
# Before
UserResource
AdminDashboard

# After
IronAdmin::Resources::UserResource
IronAdmin::Dashboards::AdminDashboard
```

#### 7. Delete old files

After verifying the new structure works, remove any leftover files from `app/iron_admin/` root:

```bash
# Only delete resource/dashboard files, keep the directory and any other files
rm -f app/iron_admin/*_resource.rb
rm -f app/iron_admin/*_dashboard.rb
```

### What does NOT change

- **Routes** -- No changes needed. The engine mount point and all URL paths remain the same.
- **Configuration** -- `IronAdmin.configure` blocks work exactly as before.
- **Initializers** -- `config/initializers/iron_admin.rb` requires no changes.
- **Resource DSL** -- All DSL methods (`field`, `searchable`, `filter`, `scope`, `action`, `menu`, etc.) work identically.
- **Model inference** -- `IronAdmin::Resources::UserResource` still maps to the `User` model automatically.
- **ResourceRegistry lookups** -- Resources are still registered and looked up by model name (e.g., `"users"`), so controllers and routes work without changes.

### New projects

If you run `rails generate iron_admin:install` or `rails generate iron_admin:resource User` on version 0.5.0, the generators automatically create files in the new namespaced structure. No manual migration is needed for new projects.
