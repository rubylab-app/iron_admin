# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **HTTP REST API Adapter** — Manage resources from external REST APIs with convention-over-configuration:
  - Fields auto-discovered from first API response (no manual declaration needed)
  - Resource path inferred from name (`ProductResource` → `GET /products`)
  - Lazy chainable `Http::Query` scope (no HTTP until records accessed)
  - Full CRUD via standard REST verbs (GET/POST/PATCH/DELETE)
  - `TypeInferrer` maps JSON values to IronAdmin field types automatically
  - `HttpQueryBuilder` translates operator filters to query parameters
  - Configurable: global `http_base_url` and `http_headers` in IronAdmin config
  - Configure per-resource: `self.adapter_class = :http`

- **Mongoid Adapter** (#50) — Full MongoDB support via a new `IronAdmin::Adapters::Mongoid` adapter:
  - Implements all 35 adapter interface methods (31 original + 5 new)
  - `ColumnDescriptor` maps Mongoid field types to IronAdmin symbol types
  - `AssociationWrapper` normalizes embedded associations (`embeds_many` → `:has_many`, `embeds_one` → `:has_one`)
  - `MongoidQueryBuilder` for operator filters using `$regex` and MongoDB comparison operators
  - Case-insensitive regex search with `Regexp.escape` for injection prevention
  - Transaction fallback for standalone MongoDB (yields without wrapping)
  - `unscope_column` rebuilds criteria from selector hash
  - Configure per-resource: `self.adapter_class = :mongoid`

- **Adapter-Agnostic Controller Layer** (#50) — Controllers no longer reference ActiveRecord classes:
  - Custom exceptions: `IronAdmin::RecordNotFound`, `IronAdmin::Rollback`
  - `Adapters::Registry` for lazy loading adapters by symbol (`:active_record`, `:mongoid`)
  - `Adapters::Base` extended with 5 new abstract methods: `record_changes`, `wrap_rollback`, `query_builder_class`, `pagy_method`, `cast_boolean`
  - `Concerns::Scopeable` extracted for scope building and adapter-agnostic record finding
  - `BaseQueryBuilder` abstract class with `ActiveRecordQueryBuilder` and `MongoidQueryBuilder` subclasses
  - `Filterable` concern routes to adapter's query builder, boolean casting, and date range filtering

- **Dashboard metric icons** (#34) — `metric` DSL now accepts `icon:` keyword for Heroicon display alongside metric values.
- **Dashboard chart labels** (#35) — `chart` DSL now accepts `label:` keyword for custom display titles, falling back to `name.to_s.humanize`.

### Fixed

- **Polymorphic type inference in lazy-loaded ActiveRecord apps** (#84) — Polymorphic inverse discovery moved behind adapter hooks and ActiveRecord eager-loads model paths before scanning descendants.
- **Mongoid polymorphic type inference** (#85) — Mongoid resources now discover loaded document classes that declare matching polymorphic inverse relations through the adapter hook.
- **Composite primary keys 500 on show/edit/update/destroy** (#78) — Models declaring `self.primary_key = [:a, :b]` (Rails 7.1+ composite-PK feature) crashed with `PG::UndefinedColumn: column "<table>.id" does not exist` on every per-record action. The index page rendered fine and links pointed at `/admin/<resource>/<id1>_<id2>`, but clicking any row 500'd. Root cause: `Concerns::Scopeable#find_record` hardcoded the lookup column to `:id`. Fixed by reading `adapter.primary_key` (added to the adapter interface, defaulting to `"id"` and overridden by the AR adapter to delegate to `model_class.primary_key` and by the Mongoid adapter to return `"_id"`). When the primary key is an Array, the URL parameter is split on `_` (matching Rails' default composite-PK `to_param` join character) and the record is looked up by chaining `adapter.filter` for each segment so the lookup stays adapter-agnostic. Single-column custom primary keys (`self.primary_key = :slug`) now also resolve correctly through the same path.
- **Polymorphic `belongs_to` form: empty type dropdown by default** (#79) — Models with `belongs_to :notable, polymorphic: true` rendered an empty `<select>` for the type column on `new`/`edit` forms unless the resource explicitly declared `belongs_to :notable, polymorphic: true, types: [...]`. Without that DSL the polymorphic association was unusable in the admin (the user could neither pick a type nor an id). `FieldInferrer#polymorphic_fields` now auto-infers the valid target types by scanning `ApplicationRecord.descendants` for `has_many :<name>, as: :<polymorphic_name>` and `has_one :<name>, as: :<polymorphic_name>` declarations, filtered to STI base classes (Rails persists the base name in the `*_type` column). The explicit DSL (`belongs_to ..., types: [...]`) still overrides the inferred list. Hosts without `ApplicationRecord` (Mongoid-only `--skip-active-record` apps) get an empty Array — same as before — and must continue to declare types via the DSL.
- **`:jsonb` / `:json` columns destroyed data on edit/update** (#80) — Any model with a `:jsonb` or `:json` column rendered an edit form whose field was a plain `<input type="text">` with `value="<Hash#to_s output>"`. Submitting the form (with or without changes) replaced the structured value with a string. Two-part fix: (1) `_form.html.haml` now has a `when :json` branch that renders a `<textarea>` populated with `JSON.pretty_generate(value)`; (2) `ResourcesController#resource_params` now `JSON.parse`s incoming `:json` field params before passing them to the adapter, so the round-trip preserves the Hash/Array structure. An empty textarea clears the column (instead of storing `""`); malformed JSON drops the key from permitted params so the existing column value is preserved instead of being overwritten with the raw string.
- **`iron_admin:install_audit` required a live DB connection** (#58) — Running the audit generator on a fresh app crashed with `ActiveRecord::ConnectionNotEstablished` because `Rails::Generators::Migration#migration_template` opens an AR connection to compute the migration version. The generator now writes the migration file directly with a timestamp-based filename — no DB connection needed. `bin/rails db:create db:migrate` works in the natural bootstrap order. Re-running the generator emits a yellow `skip` if an audit migration is already present.
- **`iron_admin:install` silenced the Tailwind import skip** (#56) — When `app/assets/tailwind/application.css` didn't exist (the common `rails new --skip-bundle` path, which defers the tailwindcss installer), the install generator returned without log output and left the admin panel unstyled with no breadcrumb to the cause. The generator now also looks for the legacy `app/assets/stylesheets/application.tailwind.css` (tailwindcss-rails 3 / cssbundling-rails layout). When neither exists, it emits a yellow `skip` status line that prints the exact `@import` directive to add manually once the Tailwind file is created.
- **`BelongsToComponent` 500s on associations without `:name`** (#63) — `Resource belongs_to :foo` rendering forms (`/admin/.../new`, `/admin/.../edit`) crashed with `undefined method 'name' for an instance of <Model>` whenever the associated model didn't expose `:name`. The component's `display_method:` now defaults to `nil` and the option label is resolved by trying the explicit method (`Symbol`/`Proc`) first, then falling back through `:name`, `:title`, `:email`, `:label`, `:slug`, and finally `"<Model> #<id>"` — the same chain the `display_record_label` helper has used for show pages. Forms render even when none of the conventional label methods exist on the associated model.
- **HTTP adapter required a Ruby model class** (#64) — Defining a Resource with `self.adapter_class = :http` per the documented "no model needed" promise crashed at registration: `Resource.model` always called `name.constantize`, which raised `NameError` because no `Product` constant existed. `Resource.model` is now adapter-aware: when `adapter_class == :http` it returns a new `IronAdmin::Adapters::Http::ModelProxy` that exposes `model_name.plural` / `model_name.human` (the minimum needed for routing and labels) without requiring a Ruby class. HTTP adapter docs now spell this out explicitly.
- **Non-AR resources silently fail to register** (#62) — Mongoid, HTTP, and custom-adapter resources never made it into the registry, so every resource page returned 404. Root cause: `Resource.inherited` fires before the subclass body has executed, so `self.adapter_class = :mongoid` (or similar) hadn't taken effect when `register_soft_delete_features` ran. The eager call would crash on the wrong adapter and the failure was silently swallowed by `rescue NameError`. Registration now happens in two phases: `Resource.inherited` adds the class to the registry first (using a class-name-derived key so adapter-driven `resource_name` lookups can't block insertion), then the engine's `to_prepare` calls `IronAdmin::ResourceRegistry.finalize!` after every class body has fully evaluated. `register_soft_delete_features` is now idempotent so it can safely run twice without duplicating the `:restore` action. Failures during `finalize!` are logged through `Rails.logger.warn` instead of being silently dropped.
- **Boot crashes when DB is unreachable** (#59) — Loading any resource crashed the whole Rails app with `ActiveRecord::ConnectionNotEstablished` when the database host was down (transient outage, Docker container not yet started, `bin/rails db:create` on a clean machine). The `register_soft_delete_features` rescue list now also catches `ActiveRecord::ConnectionNotEstablished` and logs a warning instead of bubbling the error. The rescue list is built lazily through `IronAdmin.db_unreachable_exceptions` so the gem stays usable on `--skip-active-record` hosts where `ActiveRecord` isn't loaded at all.
- **Policy `deny` method** (#32) — Implemented the `deny` DSL method in `Policy`, which was documented but raised `NoMethodError`. Deny rules take precedence over allow rules and support optional `if:` conditions. Alias resolution (`:show`/`:index` ↔ `:read`) applies to deny rules.
- **Custom actions blocked by Policy** (#38) — Custom actions (`action`/`bulk_action`) were blocked with 403 when a `policy` block was defined. Custom actions are now allowed by default unless explicitly restricted by applicable `allow` or `deny` rules. Action names are normalized to symbols for consistent lookup.
- **`has_many` string resource crash** (#33) — `has_many`, `has_one`, and `habtm` association methods crashed with `NoMethodError` when `resource:` was passed as a string. String values are now constantized, class values used directly, and registry lookup is the fallback.

### Documentation

- **Tailwind CSS prerequisites** (#37) — Added prerequisites section to quick-start guide specifying `tailwindcss-rails` >= 4.0 is required.
- **Tool namespace in docs** (#36) — Fixed tool examples in extending guide to use the correct `IronAdmin::Tools::` module nesting required by Zeitwerk autoloading.
- **Policy docs** (#32) — Clarified `deny` documentation and corrected `deny` `if:` docs to receive the current user (consistent with `allow`).
- **Custom adapter guide** — Comprehensive guide for building custom adapters: all 35 methods with signatures, return types, duck type contracts, QueryBuilder integration, testing patterns, and implementation checklist.
- **`Resource.menu` docstring `:section` vs `:group`** (#57) — The YARD docstring on `Resource.menu` documented `@option options [String] :section`, but `ResourceRegistry#grouped` (and every existing dummy resource) keys on `:group`. The docstring now accurately documents `:group`; for backward-compat, `menu` accepts `:section` as an alias and normalizes it to `:group`.

- **Nested Forms** (#23) — Inline nested form support for has_many/has_one associations:
  - `nested: true` option on `has_many` and `has_one` DSL
  - `NestedAssociation` value object, `NestedAttributesValidator` guard
  - `Concerns::Nestable` with nested_associations reader and field resolution
  - Auto-infers child fields from `FieldInferrer` (excludes id, timestamps, FK)
  - Explicit `fields:` option to select specific child fields
  - `allow_destroy:` option controls `_destroy` parameter permitting
  - `position_field:` option enables drag-and-drop reordering
  - `NestedFormComponent` ViewComponent with child row rendering, template cloning
  - `cp-nested-form` Stimulus controller with add/remove/reorder
  - Strong params auto-permitting from nested_associations declaration
  - `Concerns::NestedPermittable` extracted for permit list building
  - i18n keys for add/remove buttons

- **Resource Adapter Pattern** (#25) — Decouples IronAdmin from ActiveRecord via an adapter layer. All controllers, helpers, components, and the FieldInferrer now call through `Resource.adapter` instead of direct ActiveRecord APIs. The `Adapters::Base` abstract class defines a 31-method interface; `Adapters::ActiveRecord` is the default implementation. Custom adapters (Mongoid, HTTP, etc.) can be plugged in via `self.adapter_class = MyAdapter`.

- **Filter Operators** (#21) — New `:string` and `:number` filter types with operator dropdowns:
  - String operators: contains, equals, starts_with, ends_with (LIKE/ILIKE with wildcard escaping)
  - Number operators: equals, greater_than, less_than, between
  - `Filters::QueryBuilder` service class with SQL injection prevention (whitelist operators, parameterized queries, quoted columns)
  - Auto-inference: string/text columns auto-infer as `:string`, integer/float/decimal as `:number`
  - `Concerns::Filterable` extracted from ResourcesController for cleaner separation
  - Stimulus controller for between operator toggle
  - i18n keys for all operator labels

- **Tool System Enhancement** (#24) — Context, DSL, authorization, and forms for tools:
  - `ToolContext` value object for request context injection (params, current_user, flash)
  - `ToolAction` value object with label, icon, confirm, form_fields, and condition authorization
  - `tool_action` class-level DSL for declarative action registration
  - `find_tool_action` lookup method
  - `context` accessor on tool instances
  - Controller: arity-based dispatch (0-arg methods skip context, 1-arg methods receive ToolContext)
  - Controller: condition-based authorization (returns 403 when denied)
  - Controller: form route for actions with form_fields
  - Enhanced show view with action buttons (respects condition visibility)
  - Backward compatible: existing tools with bare methods unchanged

- **Action Forms** (#22) — Collect user input before action execution:
  - `ActionField` value object with type validation (text, textarea, number, boolean, date, datetime, select)
  - `form_fields:` option on `action` and `bulk_action` DSL
  - `action_field` convenience constructor
  - Arity-based dispatch: 1-arg blocks (existing) unchanged, 2-arg blocks receive collected params
  - Strong parameter safety: only declared field keys are permitted
  - GET routes for action form and bulk action form rendering
  - `Concerns::ActionExecutable` extracted for arity dispatch logic
  - HAML form views with all ActionField types

### Breaking changes

- **Exception types changed.** `ActiveRecord::RecordNotFound` is now raised as `IronAdmin::RecordNotFound` from adapters and controllers. If you rescue `ActiveRecord::RecordNotFound` in middleware or custom code that wraps IronAdmin, update to rescue `IronAdmin::RecordNotFound` instead.
- **`adapter_class` default is now a symbol.** `Resource.adapter_class` defaults to `:active_record` (a Symbol) instead of `IronAdmin::Adapters::ActiveRecord` (a Class). Tests that assert `adapter_class == IronAdmin::Adapters::ActiveRecord` must change to `adapter_class == :active_record`. Custom adapters passed as classes still work.
- **`Filters::QueryBuilder` is now `Filters::ActiveRecordQueryBuilder`.** The original `QueryBuilder` constant is preserved as an alias for backward compatibility, but code that subclasses `QueryBuilder` should update to `ActiveRecordQueryBuilder`.
- **New abstract methods on `Adapters::Base`.** If you have a custom adapter, implement: `record_changes(record)`, `wrap_rollback(&)`, `query_builder_class`, `pagy_method`, `cast_boolean(value)`.

### Migration notes from 0.5.0

All three features are **fully backward compatible** — no code changes are required. However:

- **`auto_inferred_filters` now returns more filters.** In addition to enum-based `:select` filters, it now auto-infers `:string` filters for string/text columns and `:number` filters for integer/float/decimal columns. If your tests assert on `auto_inferred_filters.length` or `all_filters.length`, they may need updating. These auto-inferred filters only appear in the filter bar UI when explicitly declared via `filter :name, type: :string`.

- **Internal AR calls are now routed through the adapter.** If you were monkey-patching or overriding controller/helper methods that called `@resource_class.model.where(...)` or similar AR APIs directly, switch to `@resource_class.adapter.filter(scope, column, value)` or the corresponding adapter method.

- **Action blocks now support 2-arg arity.** Existing 1-arg action blocks continue to work unchanged. Only blocks with arity 2 receive the new `params` hash. No action is required unless you want to use the new `form_fields:` option.

## [0.5.0] - 2026-02-16

### Changed

- **Namespaced resources and dashboards** — Resource and dashboard classes are now organized under `IronAdmin::Resources` and `IronAdmin::Dashboards` modules respectively. This prevents namespace pollution in host applications and provides better code organization.
  - Resource files: `app/iron_admin/user_resource.rb` → `app/iron_admin/resources/user_resource.rb`
  - Dashboard files: `app/iron_admin/admin_dashboard.rb` → `app/iron_admin/dashboards/admin_dashboard.rb`
  - Resource classes: `UserResource` → `IronAdmin::Resources::UserResource`
  - Dashboard classes: `AdminDashboard` → `IronAdmin::Dashboards::AdminDashboard`
  - Engine autoloading uses Zeitwerk `push_dir` with `namespace: IronAdmin` for correct constant resolution
  - Model inference updated to strip `IronAdmin::Resources::` prefix automatically
  - Generators (`iron_admin:install`, `iron_admin:resource`) output files to the new directory structure with proper namespacing

### Migration guide

See [UPGRADING.md](UPGRADING.md) for detailed step-by-step migration instructions.

- 1155 tests with 95%+ coverage

## [0.4.0] - 2026-02-13

### Changed

- **Gem renamed from `command_post` to `iron_admin`** — The `command_post` name was taken on RubyGems by an abandoned gem (last updated 2013), and the hyphenated `command-post` implied an incorrect `Command::Post` namespace. The new name `iron_admin` (`IronAdmin`) is available on RubyGems and unambiguous.
  - Ruby module: `CommandPost` → `IronAdmin`
  - Gem name: `command_post` → `iron_admin`
  - All file paths, require statements, config keys, and table names updated
  - i18n namespace: `command_post:` → `iron_admin:`
  - Generator names: `command_post:install` → `iron_admin:install`, `command_post:resource` → `iron_admin:resource`, `command_post:install_audit` → `iron_admin:install_audit`
  - Audit table: `command_post_audit_entries` → `iron_admin_audit_entries`
  - Removed `lib/command-post.rb` shim file (no longer needed)

### Migration guide

To upgrade from CommandPost 0.3.0:

1. Update your Gemfile: `gem "iron_admin"` (was `gem "command_post"`)
2. Rename `app/command_post/` → `app/iron_admin/`
3. Rename `config/initializers/command_post.rb` → `config/initializers/iron_admin.rb`
4. Replace `CommandPost` with `IronAdmin` in all resource and configuration files
5. Update `require "command_post"` → `require "iron_admin"` if used explicitly
6. Update mount point: `mount IronAdmin::Engine, at: "/admin"` (was `CommandPost::Engine`)
7. If using audit logging with database storage, rename the table: `rename_table :command_post_audit_entries, :iron_admin_audit_entries`

## [0.3.0] - 2026-02-12

### Added

- **New Field Types**
  - File field (`:file`) — ActiveStorage `has_one_attached` with upload, preview, and delete
  - Files field (`:files`) — ActiveStorage `has_many_attached` for multi-file uploads
  - Rich text field (`:rich_text`) — ActionText Trix editor integration
  - Password field (`:password`) — Secure password input with masking
  - Tags field (`:tags`) — Tag input with add/remove, comma-separated storage
  - Markdown field (`:markdown`) — Monospace text area for markdown content
  - URL field (`:url`) — Clickable links on show/index, URL input on forms
  - Email field (`:email`) — Mailto links on show/index, email input on forms
  - Color field (`:color`) — Color swatch display, picker + hex input on forms
  - Currency field (`:currency`) — Formatted display with configurable symbol prefix

- **Association Support**
  - `has_one` association support with show page display and View link
  - `has_and_belongs_to_many` association support with checkbox UI on forms and badge display
  - Polymorphic `belongs_to` associations — Auto-detection in `FieldInferrer`, type + ID selector on forms, linked display on show/index

- **Display Improvements**
  - Boolean icons — Check/X icon display replacing raw true/false
  - Date and datetime formatting — Human-readable date display (e.g., "January 15, 2026")
  - Index text truncation — Long text fields truncated to 50 chars with tooltip
  - FIELD_DISPLAY_METHODS dispatch hash for faster field rendering
  - Sort direction chevron indicators on table column headers
  - Sticky actions column on horizontal scroll

- **Extensibility**
  - Custom field type API (`FieldTypeRegistry`) — Register custom fields with display/index_display blocks and optional form components or partials
  - Custom tools — `Tool` base class with `ToolRegistry`, `ToolsController`, routes, and sidebar integration

- **i18n Support**
  - All UI strings externalized to `config/locales/en.yml` (renamed to `iron_admin:` namespace in 0.4.0)

- **Chart Improvements**
  - Per-chart and theme-level color customization
  - Chart.js vendored and loaded from gem assets
  - `main_bg` theme property for background color

### Changed

- Migrated inline JavaScript to Stimulus controllers (`cp-bulk-select`, `cp-chart`) shipped as ES modules via importmap
- Bulk actions moved to floating toolbar
- 1154 tests with 95%+ coverage

### Fixed

- Render badge fields as select dropdown in forms
- User-defined scopes now appear before soft delete scopes
- Pagination params preserved across bulk actions
- Dashboard chart rendering and initialization
- Dashboard recent tables display association names correctly
- Route helper delegation in RecentTableComponent
- Restore button only shown on soft-deleted records
- Soft-deleted records accessible in show/edit/destroy views
- Search bar position consistent in index view
- Index table horizontal overflow handling

## [0.2.0] - 2026-02-07

First public release.

### Added

- **Core Features**
  - Zero-configuration CRUD operations from database schema
  - Resource DSL for customizing fields, filters, scopes, and actions
  - Dashboard builder with metrics, charts, and recent records widgets
  - Theme system with fully customizable Tailwind CSS classes
  - Built-in policy system for authorization
  - Global search across all resources
  - CSV and JSON export functionality

- **Authorization System**
  - Policy-based authorization integrated into ResourcesController
  - Field visibility enforcement (`field.visible?(user)`)
  - Field readonly enforcement in form components (`field.readonly?(user)`)
  - Custom action and bulk action authorization

- **Performance Improvements**
  - Automatic association preloading to prevent N+1 queries
  - BelongsTo component pagination (default limit 100)
  - BelongsTo autocomplete component for large associations

- **Soft Delete Support**
  - Auto-detection of `deleted_at` column
  - Auto-registered `with_deleted` and `only_deleted` scopes
  - Auto-registered `restore` action

- **Audit Logging**
  - Built-in audit log with `AuditLog.log(event)`
  - Audit log viewer at `/admin/audit`
  - Enable with `config.audit_enabled = true`
  - Optional database persistence with `config.audit_storage = :database`
  - 100% optional - works without any configuration
  - Graceful fallback to memory if database table doesn't exist

- **Multi-Tenant Support**
  - `config.tenant_scope` for automatic query scoping
  - Applied to all resource queries (index, show, edit, update, destroy, exports, bulk actions)

- **Advanced Search**
  - Field-specific search syntax (`email:john@example.com`)
  - Date range search (`created_at:2025-01-01..2025-12-31`)
  - Search respects field visibility (security)

- **Convention-over-Configuration Enhancements**
  - Auto-generate select filters for model enums
  - Default badge colors for common status values (active, pending, completed, etc.)
  - Policy instances cached at Resource class level for performance

- **Comprehensive ViewComponent Library**
  - UI: Badge, Button, Card, Alert, Modal, Dropdown, Tooltip, Pagination, Scopes, EmptyState
  - Form: TextInput, Select, Checkbox, Textarea, DatePicker, BelongsTo, FieldWrapper
  - Filter: Search, SelectFilter, DateRange, BarComponent
  - Resource: DataTable, ShowField, Actions, Breadcrumb, BulkActions, RelatedList
  - Dashboard: Chart, StatsGrid, ActivityFeed, QuickLinks, MetricCard, RecentTable

### Fixed

- Export error handling for missing fields and type coercion
- Custom actions wrapped in database transactions with proper error handling
- Date filter parsing for invalid dates
- Filter bypass attempts via URL manipulation
- **Security**: Field visibility now enforced in exports (CSV/JSON)
- **Security**: Field visibility now enforced in search queries
- **Security**: `execute_action` error handling order (validates action before finding record)
- **Security**: Export controller now respects tenant scoping
- **Security**: Show action now requires authorization (`:read` permission)
- **Security**: Bulk actions validate all selected records are accessible in tenant scope
- **Security**: Policy supports bidirectional action aliases (`:show`/`:index` ↔ `:read`)
- AuditEntry.table_exists? now handles database errors gracefully

### Changed

- 997 tests with 95%+ coverage
- 100% YARD documentation coverage
- Refactored form components to use shared `FormInputBehavior` concern
- Policy instances now cached at Resource class level
- Field visibility filtering applied consistently in index, show, forms, exports, and search

[Unreleased]: https://github.com/rubylab-app/iron_admin/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/rubylab-app/iron_admin/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/rubylab-app/iron_admin/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/rubylab-app/iron_admin/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/rubylab-app/iron_admin/releases/tag/v0.2.0
