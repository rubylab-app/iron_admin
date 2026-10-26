# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] - 2026-10-25

> **Upgrading from 0.6.0?** IronAdmin 0.7.0 requires **Ruby >= 3.3** and **Rails >= 8.0.4**, raises several dependency floors, and tightens authorization, so some requests that used to succeed now return `403` or `404`. Entries marked **Breaking** need attention, and UPGRADING.md lists every change that may need action, including the responsive layout markup changes (`p-8` padding, off-canvas sidebar, overlay classes). Read the [0.7.0 upgrade guide](https://github.com/rubylab-app/iron_admin/blob/main/UPGRADING.md) before upgrading.

### Added

- **Expanded dashboard chart types** — The `chart` DSL now supports four new types in addition to `:line`, `:bar`, `:pie`, and `:doughnut`:
  - `:area` — explicit, intention-revealing name for a filled line chart (`:line` remains filled for backward compatibility)
  - `:horizontal_bar` — bar chart with the category axis on the y-axis (great for long labels)
  - `:radar` — radar/spider chart for multivariate comparisons
  - `:polar_area` — polar area chart for proportions with magnitude
  - IronAdmin types map to the correct Chart.js primitives internally (`:area`/`:horizontal_bar`/`:polar_area` → `line`/`bar` with `indexAxis: y`/`polarArea`).
- **Progress (gauge) dashboard widget** — New `progress` DSL primitive renders a value as a proportion of a target, with the value, target, and percentage displayed as a horizontal bar. Supports `max:`, `format:` (`:number`/`:currency`/`:percentage`), `label:`, and a per-widget `color:` (defaults to the theme chart border color). Rendered by the new `IronAdmin::Dashboards::ProgressComponent`.
- **Plugin / community extension system (experimental, proof of concept)** — foundation for packaging IronAdmin extensions as redistributable gems. ⚠️ **This API is experimental and unstable until 1.0** — it is not covered by the zero-breaking-changes invariant and may change or be removed before general availability.
  - `IronAdmin::Plugin` base class with a declarative DSL (`plugin_name`, `plugin_version`, `requires_iron_admin`) and a `setup` block.
  - `IronAdmin.register_plugin` / `IronAdmin::PluginRegistry` — explicit, idempotent registration and activation (re-activated on engine reload).
  - `IronAdmin::Plugin::Registration` facade — the (experimental) plugin API surface — with three working extension points: custom sidebar `menu_item`s, global `component` overrides (the same as `config.components`), and `field_type` registration.
  - `IronAdmin::MenuItem` + `IronAdmin::MenuRegistry` — custom sidebar links that are not resource- or tool-derived. The sidebar shows them after resources and tools, grouped by `group` (default "Plugins") and ordered by `priority`. They are not filtered by any resource policy.
  - Version-compatibility enforcement via `IronAdmin::IncompatiblePluginError` (and `IronAdmin::PluginError`).
- **Component overrides by class name** — A component override can be a class name String (for example `config.components.navbar = "MyNavbarComponent"`), looked up when the page renders. Use a String in an initializer: Rails raises `NameError` when an initializer references a class from `app/components`.
- **Component slot contract** — Each override slot passes a documented set of keyword arguments (`IronAdmin::Configuration::Components::SLOTS`). A component receives only the ones its `initialize` declares, or all of them with `**options`. The navbar slot also passes `title:`.
- **Dependabot** — Configuration for the root bundle, the docs site bundle and GitHub Actions: weekly grouped updates with a 7-day cooldown.
- **Stimulus controllers `cp-alert`, `cp-color-field` and `cp-modal`** — `cp-alert` removes a dismissible `IronAdmin::Ui::AlertComponent`, `cp-color-field` keeps the color picker and the hex input of a `:color` form field in sync, and `cp-modal` closes a dismissible `IronAdmin::Ui::ModalComponent`. `iron_admin/index.js` registers all three, and the engine import map pins them as `iron_admin/controllers/cp_alert_controller`, `iron_admin/controllers/cp_color_field_controller` and `iron_admin/controllers/cp_modal_controller`.
- **Translation keys** — `iron_admin.errors.forbidden.{title,message}`, `iron_admin.errors.not_found.{title,message}`, `iron_admin.errors.back_to_resource`, `iron_admin.errors.back_to_dashboard`, `iron_admin.alerts.dismiss`, `iron_admin.resources.action.confirm`, `iron_admin.imports.preview.import_button` (pluralized), `iron_admin.fields.boolean_true`, `iron_admin.fields.boolean_false`, `iron_admin.fields.color_picker_label`, `iron_admin.fields.color_invalid`, `iron_admin.fields.polymorphic_record_label`, `iron_admin.resources.index.search_label`, `iron_admin.resources.index.select_all`, `iron_admin.resources.index.select_record`, `iron_admin.filters.from_label`, `iron_admin.filters.to_label`, `iron_admin.filters.operator_label` and `iron_admin.filters.upper_value_label`. Apps that ship their own IronAdmin translations should add them (see UPGRADING.md).

### Changed

- **Breaking: Ruby >= 3.3 and Rails >= 8.0.4 are now required.** Ruby 3.2 and Rails 7.1/7.2 are no longer supported. The Rails floor is 8.0.4 because Rails 8.0.0–8.0.3 break `as: :html` integration-test requests (`NoMethodError: undefined method 'to_html' for an instance of Hash`). On Rails 8.0, keep `json` below 3.0. See UPGRADING.md.
- **Breaking: tighter dependency floors.** `pagy` is now `>= 43.7.1, < 44`: the engine has always needed `Pagy::Method` (pagy 43+), the old `>= 6.0` allowed versions that fail to load, and 43.7.1 is the first release that renders malformed or huge `page` params (`0`, `abc`, `page[]=1`, `2**63`) instead of raising a `500`. `view_component` is now `>= 4.0, < 5`, because no 3.x release works on Rails 8. `turbo-rails` is now `>= 2.0.6`, because 2.0.0–2.0.5 crash at eager-load boot when Action Cable is not loaded.
- **Breaking: `importmap-rails` is now a declared runtime dependency (`>= 2.0`), and the engine requires it.** The engine layout calls `javascript_importmap_tags`, so hosts without importmap-rails got a `NameError` on every admin page. Hosts that pin importmap-rails 1.x must upgrade it.
- **Breaking: `Resource.component` raises `ArgumentError` for slots a resource cannot override.** The valid slots are `:table`, `:form`, `:filter_bar` and `:search`. `:index`, `:show` and `:row`, which only an old code comment mentioned and which never did anything, now raise at boot. `:navbar`, `:sidebar` and `:shell` are global only (`config.components`).
- **Breaking: Component overrides are checked when they are set.** An override that is not a `ViewComponent::Base` subclass, takes a positional argument, or requires a keyword its slot never passes raises `ArgumentError`. A class name is checked when it is first looked up. A `fields[type]` component is checked when its form input first renders.
- **Mobile responsiveness** — Audited and improved the admin UI on small viewports:
  - Sidebar is now an off-canvas drawer below the `lg` breakpoint, toggled by a hamburger button in the navbar, with a tap-to-dismiss translucent backdrop (`bg-gray-900/50`), a close button, and Escape-to-close (via a new `cp-sidebar` Stimulus controller). It remains statically positioned on desktop, so the desktop layout is unchanged. The `cp-sidebar` controller is pinned in the engine importmap; without the pin, the browser could not resolve `iron_admin/index.js`, and none of IronAdmin's Stimulus controllers registered.
  - Page containers use responsive padding (`p-4 sm:p-6 lg:p-8`) instead of a fixed `p-8` across the dashboard and the index, show, new, edit, imports, audit, search, tools, and action-form views. The bulk-action form still uses `p-8`.
  - Wide tables that lacked a scroll container are now wrapped in `overflow-x-auto` (dashboard recent tables, related lists, the audit log table, and `DataTableComponent`).
  - Show-page detail rows stack label above value on mobile and switch to the side-by-side layout at `sm`.
  - Index/show/imports header rows and action button groups now wrap instead of overflowing; scope tabs scroll horizontally when numerous; the audit filter row stacks vertically on mobile.
- **Breaking: Generic message for unexpected errors** — When a custom action, bulk action, or import raises an unexpected exception, the user now sees `iron_admin.errors.unexpected` ("Something went wrong. Please try again.") instead of the exception message, and the exception is logged as `[IronAdmin] <class>: <message>`. Import validation errors (`ArgumentError`) still show their own message. The `iron_admin.resources.action.failure` and `iron_admin.resources.bulk_action.failure` translations are no longer used, so host-app overrides of those keys have no effect.
- **`iron_admin:install_audit` migration version** — The generated audit migration now inherits from `ActiveRecord::Migration[<running Active Record version>]` (for example `[8.0]` or `[8.1]`), the same way Rails' own generators do, instead of a hardcoded `[7.1]`. The generator still never opens a database connection.
- **Gem contents and metadata** — The packaged gem no longer includes the Jekyll docs-site source (`docs/site/`), an internal audit, or the `Rakefile`, and now includes `CHANGELOG.md` and `UPGRADING.md`. Gem metadata adds `documentation_uri` and `bug_tracker_uri`, links `source_code_uri`/`changelog_uri` to the release tag, and drops the unused `github_repo` key.
- **CI and release pipeline**:
  - CI runs the suite on Ruby 3.3, 3.4 and 4.0 against Rails 8.0 and 8.1 (`gemfiles/rails_8_0.gemfile`, `gemfiles/rails_8_1.gemfile`; the old matrix never actually varied Rails). It also runs a minimum-versions job on Ruby 3.3 that pins every runtime dependency to its gemspec floor (`gemfiles/minimum.gemfile`), lints with RuboCop, and checks the gem package. A single "CI result" check fails unless every job succeeded.
  - The release workflow checks that the tag is exactly `v` plus the `version.rb` version before anything else, then runs the full CI workflow, then builds, verifies and pushes the gem through trusted publishing. All workflow actions are pinned to commit SHAs (configure-rubygems-credentials was on `@main`), and forks never publish.
  - The docs site workflow builds with the Ruby 3.4 series (3.2.2 is EOL and has no ubuntu-26.04 build), uses Node 24 action majors pinned to SHAs, uses a per-PR concurrency group, deploys only from `main`, and drops the stale "PROPOSED" header.
- **Alert roles and radius** — `IronAdmin::Ui::AlertComponent` uses `role="alert"` by default only for `:error` and `:warning`, and `role="status"` for `:success` and `:info`, and accepts `role:` to override it. `IronAdmin::Layout::FlashComponent` renders every flash message with `role="alert"`, because a flash message arrives already written in a new page and screen readers do not announce a newly inserted `role="status"` region. Its border radius comes from `theme.border_radius` instead of a fixed `rounded-lg`.
- **Import preview row limit** — The import preview enforces `import_options max_rows` (default 5,000). A file over the limit is rejected before the preview is shown, not only after the import is confirmed.
- **Dashboard recent table columns** — Dashboard `recent` tables show the resource's `index_fields` when declared. Otherwise they show the id, the label column (name, title, email, ...) and other short columns, plus `created_at`, instead of the first four database columns. Long or sensitive types (textarea, rich_text, markdown, json, password, ...) are skipped, and, like the index page, fields hidden from the current user are left out. `RecentTableComponent` accepts an optional `current_user:` keyword.

### Deprecated

- `IronAdmin::Adapters::Base#pagy_method` and the built-in implementations are unused: pagination always uses Pagy's default `:offset` paginator, and Pagy 43 has no `pagy_mongoid` backend. They will be removed in 0.8.0.

### Fixed

- **Breaking: authorization gaps** — `deny :read` and `deny_actions :read` now apply to the index, CSV/JSON export, autocomplete, global search, sidebar, and dashboard `recent` tables. A resource whose `policy` never allows `:read` now returns `403` on its index (before, the index stayed reachable) and disappears from the sidebar and global search. Global search also skips searchable columns hidden from the current user. Imports honor the create policy, not only `deny_actions`. The New and Import buttons on index pages and the Edit and Delete buttons on show pages now follow the resource policy as well as `deny_actions`, so users the policy denies no longer see them. Custom member action buttons on show pages follow the resource policy too (running a denied action already returned `403`).
- **Breaking: CRUD aliases** — `:delete` maps to `:destroy`, `:new` to `:create`, and `:edit` to `:update` in policies and `deny_actions`, and `deny_actions` now also treats `:index` and `:show` as `:read`. The aliases grant as well as deny: `allow :delete` now grants destroy, and `deny :delete` / `deny_actions :delete` now block it (before, neither had any effect on destroy). `deny_actions :show` or `deny_actions :index` now blocks the whole resource; before, it had no effect. A failing alias condition no longer hides a later alias rule.
- **Breaking: tool actions** — Undeclared tool URLs can only call methods defined directly on that tool class. Methods inherited from a parent tool class or included from a module now return `404` unless they are declared with `tool_action`.
- **Breaking: Readonly fields** — Values marked `readonly` are omitted from mass-assignment on create and update, including direct `POST`/`PATCH` requests.
- **Breaking: Invalid JSON** — A malformed JSON field re-renders the form with `422 Unprocessable Content` and an inline error, and does not save the record.
- **Bulk actions** — Selected ids are resolved with the resource primary key, including slug and composite keys.
- **Datetime search ranges** — `field:from..to` includes the whole end date for datetime columns.
- **Search keeps date range filters** — Submitting the index search box no longer clears an active `date_range` filter. The built-in search form and the `hidden_params` passed to a `search` override now carry `filters[<name>_from]` and `filters[<name>_to]`.
- **Breaking: Soft delete** — On models whose default scope hides deleted rows, editing, updating, or running a custom member action other than `restore` on a soft-deleted row returns `404` until it is restored. Show, restore, and destroy can still see it. The show page of such a record only offers Restore and Delete: it no longer shows the Edit button or the buttons of other custom member actions, which could only answer `404`.
- **Breaking: Export and display safety** — CSV cells that start with `=`, `+`, `-`, `@`, a tab, or a carriage return are prefixed with `'` (so negative numbers such as `-5` are exported as `'-5`), HTTP adapter ids cannot change the request path, polymorphic types must be in the field allowlist, and rich text is sanitized.
- **Breaking: Component overrides now take effect** — Before, they were stored but never used when rendering. `config.components` (`shell`, `navbar`, `sidebar`, `table`, `form`, `filter_bar`, `search`, `fields[type]`), per-resource `component :table|:form|:filter_bar|:search` overrides (which win over global ones) and plugin `admin.component` registrations all change what renders. `fields[type]` replaces the form input only; show and index display is unchanged. Pages without overrides render as before.
- **Ruby 3.4 / 4.0 loading** — `csv` and `ostruct` are now declared as runtime dependencies. They are no longer default gems (csv since Ruby 3.4, ostruct since Ruby 4.0), so under Bundler `require "iron_admin"` failed on Ruby 3.4+ with `cannot load such file -- csv`.
- **Boot crash when the host app loads ViewComponent early** — IronAdmin added `Heroicon::ApplicationHelper` to `ViewComponent::Base` from the `:view_component` load hook. Boot failed with `NameError: uninitialized constant Heroicon::ApplicationHelper` when a host initializer, or another gem's initializer, referenced `ViewComponent::Base` during boot (for example `ViewComponent::Base.include(...)`). The helper is now included in `to_prepare`.
- **PaginationComponent** — `IronAdmin::Ui::PaginationComponent` now works with Pagy 43. Before, every render raised `NoMethodError` because the component called `prev`, the non-existent `pagy_url_for`, and the protected `series`. It now builds links with `Pagy#page_url`, which keeps the current query params, and adds `aria-label` / `aria-current`. Pass it the pagy object returned by the controller `pagy` method.
- **Translucent modal overlay on Tailwind v4** — The modal overlay used `bg-opacity-75`, which Tailwind v4 removed, so it rendered solid gray. It now uses `bg-gray-500/75`. `flex-shrink-0`, also removed in v4, is replaced with `shrink-0`.
- **Focus styles on invalid inputs** — Form inputs with validation errors now keep a red border and ring on focus. The classes put the important modifier before the variant (`!focus:border-red-500`), which Tailwind generates no CSS for; they are now `focus:!border-red-500`.
- **Audit log page with database storage** — With `config.audit_storage = :database`, `/admin/audit` raised `NoMethodError` (a `500`) as soon as one entry existed, because the view expected the in-memory entry interface. Entries now render with their time, user identifier and changes, newest first (the database store listed them oldest first). The "To" date filter includes the whole day, an invalid date is ignored instead of raising, and the filter form stays visible when the filters match nothing, so they can be cleared.
- **Breaking: Secrets in audit entries** — Audit log entries and the event passed to `on_action` stored the old and new values of every changed attribute in plain text, including `:password` fields and API tokens. Those values, and every attribute matched by the host app's `config.filter_parameters`, are now recorded as `"[FILTERED]"`. See UPGRADING.md.
- **Blank password inputs** — Editing a record and leaving a `:password` field blank no longer overwrites the stored value with an empty string. Password inputs never show the stored value, so saving any edit form silently cleared it.
- **Faded nested rows while dragging** — Host apps now generate the Tailwind classes that IronAdmin's Stimulus controllers toggle. `engine.css` did not scan `app/javascript`, so the `opacity-50` that `cp_nested_form_controller` adds to a row of a sortable nested form while it is dragged produced no CSS and the dragged row did not fade. Removing a saved nested row is unchanged: the row is hidden and marked `_destroy` until the form is saved.
- **Empty id attributes** — With haml 6 or later, index rows and dashboard metric cards no longer render an invalid empty `id=""` when live updates are off.
- **Connection checkout** — Search and operator filters now borrow a connection with `with_connection` instead of calling the soft-deprecated `ActiveRecord::Base.connection` / `Relation#connection`, so they work with `config.active_record.permanent_connection_checkout = :disallowed`.
- **Published gem contents** — The published gem can no longer include repository-only files: a new gem contents check (`.github/scripts/verify_gem.rb`) runs on every PR and before `gem push`. It rejects `vendor/bundle` (43.9 MB of it leaked into the published 0.6.0), `docs/site`, specs, untracked files, missing runtime files and oversized packages.
- **Breaking: Flash messages are shown** — Flash notices and alerts are now shown in the admin layout. Every message set by create, update and destroy, member and bulk actions, imports and tools (`ctx.flash`) was lost after the redirect, including the `iron_admin.errors.unexpected` alert described under Changed. The built-in shell renders the new `IronAdmin::Layout::FlashComponent` above the page content: `notice`/`success` appear as success alerts, `alert`/`error` as error alerts, and `warning`/`info` as their own types. Other flash keys and non-string values (such as Devise's `timedout`) are ignored. A custom shell (`config.components.shell`) has to render the component itself; see UPGRADING.md.
- **Alert dismiss button** — `IronAdmin::Ui::AlertComponent`'s dismiss button now works. It pointed at an `alert` Stimulus controller that did not exist. It now uses the new `cp-alert` controller, which is registered and pinned in the engine import map. The button has an accessible label (`iron_admin.alerts.dismiss`).
- **Modal close button** — `IronAdmin::Ui::ModalComponent`'s close button and backdrop pointed at a `modal` Stimulus controller that did not exist, so a dismissible modal could not be closed. They now use the new `cp-modal` controller, Escape closes the modal too, and the close button has an accessible label (`iron_admin.modal.close`).
- **Breaking: Error pages for 403 and 404** — HTML requests that end in 403 Forbidden or 404 Not Found (policy denials, missing or soft-deleted records, unknown resources, actions and tools, and imports or export formats that are not enabled) now render a page inside the admin layout, with a message and a link back to the resource index or the dashboard. Before, the body was empty and the browser showed its own error page. Turbo form submissions, which also accept HTML, get the page too. JSON and CSV requests, and requests that accept only Turbo Streams, still get the bare status code with an empty body. The status codes did not change. A host app can replace the page with its own `app/views/iron_admin/shared/error.html.haml` (or `.erb`).
- **Imports from the UI** — Imports can now be completed from the UI. The upload form no longer goes through Turbo Drive, which discarded the preview with "Form responses must redirect to another location". The preview page now has an "Import N rows" button that imports exactly the previewed data without uploading the file again.
- **Import preview of upsert rows** — The import preview validates a row that matches an existing record on `import_upsert_key` against that record, as the import does. Rows that the import will update are no longer flagged with "has already been taken".
- **Readable import preview** — Import preview cells show plain values instead of Ruby `inspect` output: no quotes around strings, empty cells for missing values, dates and times in the show page's default formats ("Oct 20, 2026 at 10:00 AM", with no locale lookup, so a locale without `date.formats.default` or `time.formats.default` does not break the preview), and JSON for hash and array values. The row count is pluralized ("1 row detected."): `iron_admin.imports.preview.summary` is now a `one`/`other` hash.
- **Show page member actions** — The show page offers exactly the member actions `execute_action` would run: allowed by the resource policy, able to load the record, and with a passing `condition`. The Actions card is no longer rendered empty when none is offered.
- **Action forms land on the redirect target** — Action forms and bulk action forms opened by URL now land on the redirect target (the record or the index, with its flash message) after Execute, instead of replacing the page with "Content missing". The forms submit with `data-turbo-frame="_top"`.
- **Action confirmation text** — The `confirm_message` option of `action` is now used in the confirmation dialog on the show page and in `ActionsComponent`. Actions without one fall back to the new `iron_admin.resources.action.confirm` key ("Are you sure?") instead of the delete confirmation text.
- **Related lists on show pages** — has_many related lists on show pages are now rendered by `RelatedListComponent`, so their table sits in an `overflow-x-auto` container as the Mobile responsiveness entry states. The component now matches the other show page cards (no card border, `table_border` row dividers) and uses the localized "View all" label.
- **"View all" on related lists** — "View all" on a has_many related list now opens the index filtered by the parent's foreign key when the associated resource has a filter on that column (for example `filter :category_id, type: :select`). `RelatedListComponent` takes an optional `parent:` record for this. Through and polymorphic (`as:`) associations, and resources without such a filter, keep the plain index link.
- **Index URL follows sorting and pagination** — The index's `records` Turbo frame now has `data-turbo-action="advance"`. Paging, sorting and bulk actions now update the address bar and push a history entry. Before, only the frame changed, so reload, Back and copied links lost the page and sort.
- **Sorting keeps active filters** — Column-header sort links, in the built-in table and through the `base_url` passed to a `table` override (including `IronAdmin::Resources::DataTableComponent`), now keep the active filters along with the scope and search query, and go back to page 1. Before, clicking a header showed unfiltered rows while the filter panel still showed the filter as active. Sort links now load the whole page (`data-turbo-frame="_top"`), so the search and filter forms pick up the new sort.
- **Searching and filtering keep the sort** — The index search form, the `hidden_params` passed to a `search` override, the built-in filter form and its Clear link now carry `sort` and `direction`. Before, the list fell back to the default order.
- **Bulk actions return to the same list** — After a bulk action, the index keeps the scope, search, filters, sort and page it was run from, on success and on errors alike. Before, it fell back to the bare default index. The bulk form sends that state as hidden fields. Only the known index params are kept, and the redirect always targets the resource index. When the action empties the page it ran from (deleted rows, or rows that left the filter or scope), the page is capped at the list's new last page instead of landing on an empty page with no pagination. The bulk form now submits to the whole page (`data-turbo-frame="_top"`), so its flash message is shown and the search and filter forms match the list.
- **Declared filters replace inferred ones** — A filter declared with `filter` on an enum column no longer renders a second, dead select next to the auto-inferred one. The declared filter replaces the inferred filter of the same name. It offers the `options:` it lists, or the enum values when it lists none; before, the index always listed every enum value.
- **`remove_filter` and inferred filters** — `remove_filter` now removes auto-inferred enum and column filters too, as documented. It used to only remove filters declared with `filter`.
- **Export column order** — Export columns follow the order declared in `export_fields` instead of the table's column order.
- **CSV export order** — CSV exports keep the index sort order (requested or default). ActiveRecord's `find_each` dropped the ORDER BY, so CSV rows came out in primary-key order while JSON followed the sort.
- **Attachments in exports** — `:file` and `:files` attachments export as filenames (a JSON array or a comma-separated CSV cell for `:files`, blank when nothing is attached) instead of `#<ActiveStorage::Attached::One:0x...>`.
- **Rich text in exports** — `:rich_text` fields export the stored HTML in CSV and JSON. Before, they exported the content rendered through the ActionText layout: wrapped in `<div class="trix-content">` and, with `annotate_rendered_view_with_filenames` (on by default in development), surrounded by comments with the absolute paths of the templates on the server. CSV cells still get the formula prefix.
- **Form field order** — Create and edit forms now render fields in the order given to `form_fields`, as documented, instead of database column order.
- **Import field order** — The import page lists the importable fields in the order given to `import_fields` instead of database column order, and the import preview shows its columns in that order instead of the file's header order.
- **Breaking: Color field** — The `:color` form field submits a single value. Picking a color with the swatch is saved on both create and edit; before, the hex text box always overrode it. The picker and the hex box stay in sync, a blank field stays blank, and text that is not a `#rgb` or `#rrggbb` hex color is rejected in the browser with a hint instead of being saved silently. Records that store another CSS color format (such as `red` or `rgb(...)`) can no longer be saved from the form until the value is changed; see UPGRADING.md.
- **Boolean values for screen readers** — Boolean values on index and show pages now include visually hidden "Yes"/"No" text, so screen readers no longer announce an empty cell next to the check or cross icon. The text sits in a `relative` wrapper, as does the hidden "Actions" header of `DataTableComponent`, so it stays inside its table cell and a wide table scrolls in its own container instead of making the whole page scroll sideways.
- **Global search labels** — Global search results are labelled with `display_record_label`, so records with a `title` (or `label`/`slug`) show it instead of a bare `#<id>`, and records with no label column read `<Model> #<id>`.
- **Global search query** — On the search results page, the navbar search box keeps the submitted query and the heading reads `Search results for "<query>"`. The search box has an accessible name ("Search across all resources").
- **Audit log Action filter** — The audit log's Action filter lists the actions actually logged, including custom resource actions such as `deactivate` or `approve`, instead of a fixed create/update/destroy list, and shows multi-word actions as "Send now" rather than "Send_now".
- **Audit log resource labels** — The audit log's Resource column shows the resource label ("Users") instead of the stored class name (`IronAdmin::Resources::UserResource`), like the Resource filter. A logged resource that is no longer registered keeps its stored value in the column and is offered in the Resource filter under that value.
- **Breaking: Audit log for bulk actions and imports** — Bulk actions and imports are now audited like single-record changes, through the same path, so `:password` fields and `filter_parameters` stay masked and `on_action` receives every event. Before, neither left an audit entry or called `on_action`. An `on_action` callback is now called once per record of a bulk action or import (up to `import_options max_rows`, 5,000 by default). Member actions, bulk actions and imports emit their events once the transaction commits: a change that rolls back logs nothing and does not call `on_action`, and an error raised by `on_action` no longer rolls the change back. See UPGRADING.md.
  - A bulk action logs one entry per selected record under the action's name (a `bulk_action :approve` logs `approve`, like a member `action :approve`) once its block succeeds and the transaction commits. A block that returns `false` or raises logs nothing. A copy of the selection is loaded before the block runs (the block still receives an unloaded relation), so records it destroys are logged too; a block that uses `update_all` logs them with empty changes.
  - An import logs `create` or `update` for each saved row, with its changes, once the import commits. Failed rows log nothing, and an import that raises and rolls back leaves no entries and calls no `on_action`, with either audit storage. There is no separate cap: `import_options max_rows` (default 5,000) bounds the entries per import. `Import::Importer#execute!` now yields `:create` or `:update` and the record for each saved row, which is how the UI audits it.
  - A member action that returns `false` is rolled back and, unlike in 0.6, no longer logged or passed to `on_action`.
  - Adapters gain `after_commit`, which runs a block once the current transaction commits and never if it rolls back. `Adapters::Base` runs the block at once, as suits a data source without transactions; the ActiveRecord adapter waits for the commit.
- **Import rows that are not saved** — An import row whose save fails without validation errors, for example because a model callback throws `:abort` or the HTTP adapter cannot reach the API, is counted as failed with "The record could not be saved." (`iron_admin.imports.errors.not_saved`). Before, it was counted as created or updated, and this release would also have audited it.
- **Filters badge** — The Filters badge on index pages, and the `active_count` passed to a `filter_bar` override, count a string or number filter only when it has a value. The filter form always submits the operator, so applying one filter counted every operator filter and an empty form opened the panel.
- **Main landmark and skip link** — The page content area of the built-in shell is a `<main id="main-content">` element (same classes as before), and a "Skip to content" link, hidden until it is focused, comes first on the page.
- **Form labels** — The File and Format labels of the import form, and the Resource, Action, From and To labels of the audit log filters, are associated with their controls, so screen readers announce them.
- **Resource form labels** — Every control of the new and edit forms has an accessible name, and every field label points at an existing control. A `belongs_to` label points at its select (`record_<foreign_key>`), a polymorphic `belongs_to` label at its type select (the record select is named "<Field> record"), and a `:tags` label at its text input. Nested-form rows, including the "Add row" template, label each control. Radio buttons, boolean groups and has_many checkboxes are a `role="group"` (`radiogroup`) named by the field label, and each has_many checkbox has its own id. The "Remove" checkbox of a `:file` field is now `record_<field>_purge`, which its label already pointed at.
- **Accessible belongs_to autocomplete** — The autocomplete input is a combobox (`role="combobox"`, `aria-autocomplete="list"`, `aria-controls`, and `aria-expanded` and `aria-activedescendant` kept in sync by its script) over a `role="listbox"` of `role="option"` results, and the field label points at it. `BelongsToAutocompleteComponent` takes an `input_id:`; the form passes `record_<foreign_key>`.
- **Index filter and search names** — Each filter label of the built-in filter panel points at its control (the select, the value input of a string or number filter, or the From date). Operator selects are named "<Filter> operator", date range inputs "<Filter> from" and "<Filter> to", and the upper value of a "between" filter "<Filter> upper value". The search box is named "Search <resource label>". `Filters::SelectFilterComponent` and `Filters::DateRangeComponent` label their controls the same way, `Filters::SearchComponent` takes `resource_class:` for its name, and the hidden `q`, `scope` and preserved filter fields of the filter panel, `Filters::BarComponent` and `Filters::SearchComponent` no longer have ids that duplicate the search box's `q` or a filter control's id.
- **Bulk-select checkboxes** — The header checkbox is named "Select all" and each row checkbox "Select <record label>", so screen readers no longer announce unnamed checkboxes.
- **Audit log filter row** — The Resource and Action selects, the From and To date inputs, and the Filter and Clear buttons share one height, so their labels and the buttons line up at every width. Before, the date inputs and their labels sat 4px lower than the selects.
- **Dashboard metric labels** — Dashboard metric card labels no longer touch their icon: the metrics grid keeps two columns until the `xl` breakpoint, and the card adds a gap and lets the label wrap. The value sits on its own row below the label and the icon, a size smaller at the `xl` breakpoint, so a value such as `$123,456.78` is never split across two lines.
- **Index pages past the last page** — An index page past the last page (for example after a bulk action emptied it, or from a stale link) now redirects to the last page, keeping its scope, search, filters and sort, instead of showing an empty list with no pagination.
- **Import files larger than 12 MB** — The import preview rejects files larger than 12 MB with "The file is larger than 12 MB. Split it into smaller files." (`iron_admin.imports.errors.file_too_large`) instead of showing an Import button that fails with a server error: Rack buffers at most 16 MiB of non-file multipart fields, and the preview page carries the file back Base64-encoded.
- **Import buttons** — The Preview and "Import N rows" buttons now have the size and font of the Cancel and Back buttons next to them, and a gap between the icon and the text.
- **Dashboard recent records order** — Dashboard `recent` tables list the newest records first (by `created_at`, then primary key; or by primary key when there is no `created_at`) unless the given scope already orders them.

### Security

- **Breaking: No inferred filters on secret fields** — Filters are no longer auto-inferred for fields declared `type: :password`, `type: :hidden` or `visible: false`. Before, any user who could read the resource could run `starts_with` queries on a password column and recover its value one character at a time. A filter declared by hand on a `type: :password` or `type: :hidden` field is still honoured. A `visible: false` field is hidden from every user, so a filter declared on it is never offered or applied.
- **Breaking: No search or sort on secret fields** — The index search box (including `field:value` queries), global search, autocomplete and exports no longer search fields declared `type: :password` or `type: :hidden`, even when `searchable` lists them, and `sort` on such a column falls back to the default order. Before, `?q=api_token:mk_` gave the same one-character-at-a-time oracle on a `:password` field that inferred filters did.
- **Breaking: Password and hidden fields in exports** — CSV and JSON exports leave `:password` and `:hidden` fields out by default. A `:hidden` field listed in `export_fields` is exported with its value. A `:password` field listed there is exported as `[FILTERED]`, never as its raw value.
- **Dashboard recent tables follow read policy and tenant scope** — Dashboard `recent` tables are no longer rendered for resources the current user cannot read (`deny :read`, a conditional `allow :read`, or `deny_actions :read`), and they apply `tenant_scope` after their `scope:`. Before, a resource that returned `403` on its index still listed its newest records on the dashboard, across tenants.
- **Breaking: Export formats** — Exports now honour the `exports` DSL: a format the resource does not enable (or any format after a bare `exports`) returns `404` instead of being served.
- **Import files must be uploads** — Imports only accept a real multipart upload as `file`. A plain string `file` parameter was read as a path on the server, so a user allowed to create on an import-enabled resource could preview server files or import them into the database.

### Documentation

- Added `docs/plugin-system-design.md` — design proposal for the plugin/community extension system: philosophy, extension points, packaging model, registration API, versioning/security considerations, an end-to-end example, and the deferred work + decisions requiring maintainer sign-off. It now describes menu items and component overrides as rendered.
- **Documentation site** — A navigable, searchable documentation site built with [Jekyll](https://jekyllrb.com/) and the [`just-the-docs`](https://just-the-docs.com/) theme lives under `docs/site/` and is published to GitHub Pages at https://rubylab-app.github.io/iron_admin/:
  - Tooling rationale (Jekyll + just-the-docs vs. MkDocs Material / Docusaurus) in `docs/site/README.md`
  - Section structure: Getting Started, Guides (Resource DSL, Dashboards, Fields, Theming, Components), Adapters, Authorization, Imports & Exports, Tools, Reference, Upgrade Guide, FAQ
  - Installation, Quick Start, and Resource DSL are fully migrated; the other sections are stubs that link to their source files in the repo
  - Client-side search, sidebar navigation, and "Edit this page on GitHub" links
  - `.github/workflows/docs.yml` builds the site on pull requests that touch `docs/` or the workflow itself, and deploys it to GitHub Pages only when a maintainer runs it manually (`workflow_dispatch`) on `main`
  - Fixed six internal links that returned 404 on the live site; they now use Jekyll's `{% link %}` tag, so the PR build fails if a target goes missing
- **Supported versions** — The README, FAQ, installation guides, and docs site list Ruby >= 3.3 and Rails >= 8.0.4; the installation guides also list every runtime dependency with its exact gemspec requirement. `UPGRADING.md` has a 0.6 → 0.7 section.
- **Host requirements** — Documented `tailwindcss-rails` >= 4.3 (was >= 4.0; only 4.3 and later generate the IronAdmin bridge file with `tailwindcss:engines`) and the default importmap + Stimulus JavaScript setup the admin layout relies on (`javascript_importmap_tags`, `window.Stimulus`). The FAQ no longer describes the Tailwind v3 `tailwind.config.js` setup.
- **Component overrides** — `docs/guides/components.md` documents every slot, the keyword arguments it passes, the per-resource slots, plugin overrides and field input overrides.
- **Authorization and fields guides** — Describe what `:read` and `:create` now cover, the alias table for policies and `deny_actions`, the policy-gated buttons, and how readonly fields are handled.
- **Custom adapters guide / UPGRADING** — `Adapters::Base#pagy_method` is documented as unused. Pagination always uses Pagy's `:offset` paginator, and Pagy 43 has no `pagy_mongoid` backend.
- **Component namespace** — The component docs use `IronAdmin::Ui::` (44 references said `IronAdmin::UI::`, which does not exist), and the `PaginationComponent` docs say the pagy object must come from the controller `pagy` method.
- **Release process** — `RELEASING.md` describes the new release pipeline and CI jobs, the docs-site redeploy after a release, and the one-time admin setup: require "CI result" in the "Protect main" ruleset, restrict the release environment to `v*` tags, bind the RubyGems trusted publisher to that environment, and protect release tags.
- **Contributing** — `CONTRIBUTING.md` states Ruby >= 3.3, the lint command CI runs (`bundle exec rubocop . .github/scripts`), how to reproduce a CI gemfile leg, and the 90% coverage threshold the suite enforces.
- **Imports guide** — New `docs/guides/imports.md` documents the import DSL, the upload, preview and import flow, the `max_rows` and `preview_rows` options, the size limit of the import step (about 12 MB with Rack's default multipart limit), importing from Ruby, and what overridden import views must keep.
- **Guides match the 0.7.0 behaviour** — The components guide documents `FlashComponent`, the alert roles and the `cp-alert` controller, what sits inside the `records` Turbo frame, and what `base_url` and `hidden_params` now carry. The authorization guide documents the 403/404 page and how to override it. The resources guides (`docs/guides/resources.md` and the docs site Resource DSL page) cover declared versus inferred filters, `remove_filter`, `options:` for select filters (the README and quick start said `choices:`, which filters ignore), `form_fields` order, `confirm_message`, the foreign-key filter behind "View all", and the export rules. The fields, export, dashboard, custom adapters, extending (i18n keys added in 0.7.0, view overrides), troubleshooting and routes pages follow the fixes, and the audit migration command reads `iron_admin:install_audit`.

## [0.6.0] - 2026-06-28

> ⚠️ **Upgrading from 0.5.0?** Plain ActiveRecord applications need no code changes, but this release carries **breaking changes** for code that touches IronAdmin internals or maintains a custom adapter. Read the [Breaking changes](#breaking-changes) section below and the [0.6.0 upgrade guide](UPGRADING.md) before upgrading.

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
- **CSV/JSON imports** (#53) — Resources can opt in to uploads with `imports :csv, :json`, constrain importable fields, configure upsert keys, preview mapped rows, and create/update records through adapter-driven persistence.
- **Polling live updates** (#54) — Added opt-in `live_updates = :polling`, a thread-safe poll cache, Turbo Stream broadcaster, live polling endpoint, dashboard `live:` options, and stable resource/metric DOM targets.

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

### Fixed

- **Tenant boundaries for global search, import upserts, and direct action routes** (#98) — Global `/admin/search` now applies the configured tenant scope per resource, import upsert lookups only match records inside tenant scope, and direct single-record action form/execute routes now enforce action `condition:` checks with `403 Forbidden` when false.
- **Mongoid adapter value handling** (#98) — Mongoid numeric filters now ignore integers outside BSON int64 range instead of surfacing `RangeError`, JSON exports preserve Hash/Array values as JSON objects/arrays, and Mongoid `Array` fields submitted by tags-style comma-separated form inputs are persisted as arrays.
- **Filtering, search, and export consistency** (#98) — CSV/JSON exports now apply the same filters, search query, scopes, sort order, tenant scope, and preloading as index views for ActiveRecord and Mongoid resources. Auto-inferred filters now render in the index UI while respecting field visibility, select filters with scalar string options render usable labels and values, field-specific string searches containing `..` no longer expand to an unfiltered result set, and ActiveRecord search now finds literal `%` and `_` characters.
- **Controller hardening for malformed params and missing records** (#98) — Resource show/edit/update/destroy now return 404 for missing or inaccessible records instead of surfacing `IronAdmin::RecordNotFound`; malformed array-shaped `record` params now return 400; array-shaped numeric filter params no longer crash the index view; composite-primary-key autocomplete now searches a real text column fallback and returns `to_param` ids.
- **Nested association JSON fields** (#86) — Nested forms now render `:json` child fields as pretty-printed textareas and coerce both `has_many`-style and `has_one`-style nested `*_attributes` JSON strings back into structured values.
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
- **Heroicon helper missing in `ViewComponent::Base`** (#60) — IronAdmin components that render Heroicons crashed because the icon helper was not mixed into `ViewComponent::Base`; it is now included so icons render inside any IronAdmin component.
- **Engine JavaScript not precompiled in production** (#61) — Added an `iron_admin_manifest.js` asset manifest so the engine's Stimulus controllers and bundled JavaScript are picked up by the asset pipeline and precompiled in host apps; without it the admin UI shipped no JavaScript in production.
- **Dashboard charts failed to load in production** (#74) — `chart.min.js` is now linked from `iron_admin_manifest.js` so Chart.js is precompiled alongside the rest of the engine assets and dashboard charts render in production.
- **Stale adapter cached after `adapter_class` change** (#62 follow-up) — `Resource.adapter` now invalidates its memoized adapter when `adapter_class` is reassigned, so switching adapters (for example to `:mongoid`) takes effect instead of reusing the previously built adapter instance.
- **Mongoid 9 compatibility** (#76) — The Mongoid adapter now derives the association macro from the association's class name instead of the `#macro` API that changed in Mongoid 9, restoring embedded and relational association normalization on the latest Mongoid.
- **`belongs_to` form labels on associations without `:name`** (#63 follow-up) — `new`/`edit` forms now resolve `belongs_to` option labels through the same `display_record_label` fallback chain used on show pages, so forms render readable labels even when the associated model lacks `:name`.

### Documentation

- **Tailwind CSS prerequisites** (#37) — Added prerequisites section to quick-start guide specifying `tailwindcss-rails` >= 4.0 is required.
- **Tool namespace in docs** (#36) — Fixed tool examples in extending guide to use the correct `IronAdmin::Tools::` module nesting required by Zeitwerk autoloading.
- **Policy docs** (#32) — Clarified `deny` documentation and corrected `deny` `if:` docs to receive the current user (consistent with `allow`).
- **Custom adapter guide** — Comprehensive guide for building custom adapters: all 35 methods with signatures, return types, duck type contracts, QueryBuilder integration, testing patterns, and implementation checklist.
- **`Resource.menu` docstring `:section` vs `:group`** (#57) — The YARD docstring on `Resource.menu` documented `@option options [String] :section`, but `ResourceRegistry#grouped` (and every existing dummy resource) keys on `:group`. The docstring now accurately documents `:group`; for backward-compat, `menu` accepts `:section` as an alias and normalizes it to `:group`.

### Breaking changes

- **Exception types changed.** `ActiveRecord::RecordNotFound` is now raised as `IronAdmin::RecordNotFound` from adapters and controllers. If you rescue `ActiveRecord::RecordNotFound` in middleware or custom code that wraps IronAdmin, update to rescue `IronAdmin::RecordNotFound` instead.
- **`adapter_class` default is now a symbol.** `Resource.adapter_class` defaults to `:active_record` (a Symbol) instead of `IronAdmin::Adapters::ActiveRecord` (a Class). Tests that assert `adapter_class == IronAdmin::Adapters::ActiveRecord` must change to `adapter_class == :active_record`. Custom adapters passed as classes still work.
- **`Filters::QueryBuilder` is now `Filters::ActiveRecordQueryBuilder`.** The original `QueryBuilder` constant is preserved as an alias for backward compatibility, but code that subclasses `QueryBuilder` should update to `ActiveRecordQueryBuilder`.
- **New abstract methods on `Adapters::Base`.** If you have a custom adapter, implement: `record_changes(record)`, `wrap_rollback(&)`, `query_builder_class`, `pagy_method`, `cast_boolean(value)`.

### Migration notes from 0.5.0

For plain ActiveRecord applications, 0.6.0 is **largely backward compatible** — but review the [Breaking changes](#breaking-changes) above and the [0.6.0 upgrade guide](UPGRADING.md) first, especially if you maintain a custom adapter, rescue IronAdmin's not-found exception, or subclass the filter `QueryBuilder`. Additional behavioral notes:

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

- Category D: belongs_to form fields now honor `autocomplete: true` and tenant-scoped select options.
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

[Unreleased]: https://github.com/rubylab-app/iron_admin/compare/v0.7.0...HEAD
[0.7.0]: https://github.com/rubylab-app/iron_admin/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/rubylab-app/iron_admin/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/rubylab-app/iron_admin/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/rubylab-app/iron_admin/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/rubylab-app/iron_admin/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/rubylab-app/iron_admin/releases/tag/v0.2.0
