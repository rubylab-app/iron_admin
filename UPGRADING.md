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
- dashboard `recent` tables (the table is not rendered)

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

For those models, the show page of a soft-deleted record only offers Restore and Delete. It no longer renders the Edit button or the buttons of other custom member actions, which could only answer `404`.

**Action required:** Restore a record before editing it. If a custom action has to work on soft-deleted rows, run it after `restore`. Update system specs that expect the Edit button or a custom action button on the show page of a soft-deleted record.

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

When a custom action, bulk action, or import raises an unexpected exception, admins now see "Something went wrong. Please try again." (`iron_admin.errors.unexpected`) instead of the exception message, as an error alert above the page (flash messages are now rendered, see section 18). The exception is logged as `[IronAdmin] <class>: <message>`. Import validation errors (`ArgumentError`) still show their message.

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
- Global search results are labelled like the rest of the UI (`display_record_label`): the record's `name`, `title`, `email`, `label` or `slug`, or `<Model> #<id>` when it has none. Before, a record without `name` or `email` showed `#<id>`.
- Boolean values on index and show pages are wrapped in `<span class="relative inline-flex">` with visually hidden "Yes" or "No" text (`<span class="sr-only">`) next to the icon. Specs that compare the exact icon markup, or the full text of a row, now see the wrapper and the text.
- The search results heading reads `Search results for "<query>"`, and the navbar search box keeps the query on that page.
- The audit log's Resource column shows the resource label ("Users") instead of the stored class name.
- The audit log's Action filter lists the actions that were logged, custom actions included, and action names are shown with `humanize` ("Send now") instead of `capitalize` ("Send_now").

**Action required:** Update system specs that expect `#<id>` in global search results, the old boolean markup, the fixed create/update/destroy options of the audit Action filter, the plain "Search results" heading, or class names in the audit Resource column.

### 14. Layout markup changed (responsive UI)

- Page containers use `p-4 sm:p-6 lg:p-8` instead of `p-8` on the dashboard and on index, show, new, edit, import, audit, search, tool, and action-form pages. The bulk-action form still uses `p-8`.
- Below the `lg` breakpoint (1024px), the sidebar is an off-canvas drawer, opened with the "Open menu" button in the navbar.
- Wide tables are wrapped in `overflow-x-auto`, and show-page detail rows stack vertically below `sm`.
- The built-in shell renders the page content in `<main id="main-content">` (the element was a `<div>` with the same classes), preceded by a "Skip to content" link that is visually hidden until focused. A custom shell (`config.components.shell`) should provide its own `<main>` landmark.
- Overlays use Tailwind v4 opacity modifiers (`bg-gray-900/50`, `bg-gray-500/75`) instead of `bg-opacity-*`, which Tailwind v4 removed. On Tailwind v4 the modal overlay rendered solid gray; it is translucent now.
- With haml 6 or later, index rows and dashboard metric cards no longer render an empty `id=""` when live updates are off.
- The dashboard metrics grid keeps two columns until the `xl` breakpoint (`md:grid-cols-2 xl:grid-cols-4`, was `lg:grid-cols-4`), so metric labels do not touch their icons.
- In a dashboard metric card, the label and the icon share the top row, and the value sits on its own row below them (`text-3xl`, `xl:text-2xl 2xl:text-3xl`), so a long value such as `$123,456.78` is never split across two lines.

**Action required:** Update host CSS or system specs that select `.p-8` or assume the sidebar is always visible. Run browser system specs with a window at least 1024px wide (Rails' default `screen_size: [1400, 1400]` is fine), or click "Open menu" before using sidebar links.

### 15. Component overrides now take effect

In 0.6.0, `config.components` and `Resource.component` stored overrides that nothing rendered. In 0.7.0 they are used: `config.components.shell`, `navbar`, `sidebar`, `table`, `form`, `filter_bar`, `search` and `fields[type]` change what renders, and a resource's `component :table`, `:form`, `:filter_bar` or `:search` wins over the global one for that resource. Slot overrides are checked when they are set (a `fields[type]` entry, and any class name String, is checked when it is first rendered):

- An override that is not a `ViewComponent::Base` subclass (or its class name), takes a positional argument, or requires a keyword its slot never passes raises `ArgumentError`.
- `Resource.component` raises `ArgumentError` for any slot other than `:table`, `:form`, `:filter_bar` and `:search`. That includes `:index`, `:show` and `:row`, which only an old code comment mentioned and which never did anything, and the global-only `:navbar`, `:sidebar` and `:shell`.

**Action required:** If your app sets any component override, check that the component renders what you expect, and that its `initialize` only requires keywords its slot passes (see [Components](docs/guides/components.md#overriding-components)). Remove `component :index`, `:show` or `:row` from resources; they raise at boot now. In initializers, set overrides as class name Strings (`config.components.navbar = "AdminNavbarComponent"`), because Rails raises `NameError` when an initializer references a class from `app/components`.

### 16. `Adapters::Base#pagy_method` is deprecated

`pagy_method` and the built-in implementations are unused: pagination always uses Pagy's default `:offset` paginator, which works with any scope that responds to `count`, `offset`, and `limit`. Pagy 43 has no `pagy_mongoid` backend. The method will be removed in 0.8.0.

**Action required:** None. Custom adapters can keep returning `:pagy` until 0.8.0.

### 17. Audit entries and `on_action` events: masked secrets, bulk actions and imports

The changes IronAdmin records for a create, update or destroy replace the values of `:password` fields, and of every attribute matched by your app's `config.filter_parameters`, with `"[FILTERED]"`. This applies to new audit log entries and to the `changes` of the event passed to `config.on_action`. Entries recorded before the upgrade are not rewritten.

Bulk actions and imports are now audited too. A bulk action logs one entry per selected record under the action's name once its block succeeds (a block that returns `false` or raises logs nothing), and an import logs `create` or `update` for each saved row. Both go through the same masking and call `on_action` once per record. An import can therefore call `on_action` up to `import_options max_rows` times (5,000 by default).

Member actions, bulk actions and imports emit their events once the transaction commits. A change that rolls back logs nothing and does not call `on_action`; in 0.6 a member action that returned `false` was rolled back but still logged and passed to `on_action`. An error raised by `on_action` no longer rolls the change back: the change is kept, the events after it are skipped, and the page shows the generic error message. IronAdmin waits for the commit through the adapter's new `after_commit` method, which `Adapters::Base` implements by running the block at once.

**Action required:** If an `on_action` callback needs a filtered value, read it from the record instead of `event.changes`. To keep a column visible in the audit log, remove it from `filter_parameters`. Review existing `iron_admin_audit_entries` rows for secrets stored by earlier versions. If an `on_action` callback sends mail or calls an API, make sure it can take one call per record of a bulk action or import. Do not rely on an error raised by `on_action` to undo a change; reject it in the action or a model validation instead. A custom adapter whose `transaction` is atomic should override `after_commit` to run the block after the commit (see the custom adapters guide); otherwise its events are emitted inside the transaction.

### 18. Flash messages are rendered

In 0.6.0 the admin layout never rendered the flash, so every notice and alert set by create, update, destroy, member and bulk actions, imports and tools (`ctx.flash`) was lost after the redirect. The built-in shell now renders `IronAdmin::Layout::FlashComponent` above the page content. It shows `notice` and `success` as success alerts, `alert` and `error` as error alerts, and `warning` and `info` as their own types. Other flash keys and non-string values (such as Devise's `timedout`) are ignored.

Each message is an `IronAdmin::Ui::AlertComponent` with `role="alert"`, whatever its type: the message arrives already written in a new page, and screen readers do not announce an inserted `role="status"`. On its own, `AlertComponent` now uses `role="status"` for `:success` and `:info` and `role="alert"` for `:error` and `:warning`, and takes a `role:` argument that overrides it. It takes its border radius from `theme.border_radius` instead of `rounded-lg`, and its dismiss button works through the new `cp-alert` Stimulus controller (it pointed at a missing `alert` controller).

**Action required:**

- If you set `config.components.shell`, render the flash in your shell, before the page content. The component also accepts `flash:` to pass messages explicitly.

  ```haml
  = render IronAdmin::Layout::FlashComponent.new
  = content
  ```

- If your app already rendered the flash on admin pages (for example in a custom navbar or sidebar), remove that markup, or each message shows twice.
- System specs now find the flash text in the page, with `role="alert"`, and an `AlertComponent` you render yourself with type `:success` or `:info` has `role="status"` unless you pass `role:`. Update specs that count alerts or assert on `role`.

### 19. 403 and 404 responses render a page

HTML requests that end in `403` or `404` (a policy denial, a missing or soft-deleted record, an unknown resource, action or tool, or an import or export format that is not enabled) now render the `iron_admin/shared/error` template inside the admin layout, with a message and a link back to the resource index (when the user may read it) or to the dashboard. In 0.6.0 the body was empty, and the browser showed its own error page. Turbo form submissions also accept HTML, so they get the page too. The status codes did not change, and JSON and CSV requests, and requests that accept only Turbo Streams, still get an empty body.

**Action required:**

- Update request specs that expect an empty body from an HTML request that returns `403` or `404`.
- To customize the page, add your own `app/views/iron_admin/shared/error.html.haml` (or `.html.erb`). It receives the local `error` (`:forbidden` or `:not_found`); `@resource_class` is set when the URL named a registered resource.
- If you ship your own translations, add the error page keys (section 29).

### 20. Secret fields: no inferred filters, no search or sort, and left out of exports

Filters are no longer inferred for fields declared `type: :password`, `type: :hidden` or `visible: false`. In 0.6.0 a string password column got a `:string` filter, so any user who could read the resource could recover the value one character at a time with `starts_with`. A field whose `visible:` is a proc keeps its inferred filter, which is only offered to users who can see the field.

The same probe worked through search, so fields declared `type: :password` or `type: :hidden` are no longer searched by the index search box (including `field:value` queries such as `?q=api_token:mk_`), global search, autocomplete or exports, even when `searchable` lists them. A `field:value` query on such a field leaves the list unfiltered, and `sort` on such a column falls back to `config.default_sort`.

CSV and JSON exports now leave `:password` and `:hidden` fields out. A `:hidden` field listed in `export_fields` is exported with its value. A `:password` field listed there is exported as `[FILTERED]`, never as its value.

**Action required:**

- To filter on a `type: :password` or `type: :hidden` field anyway, declare the filter with `filter`; a declared filter on those types is still honoured. A field declared `visible: false` is hidden from every user, and filters follow field visibility, so a filter on it is never offered or applied. Use a `visible:` proc instead if some users need to filter on it.
- If users search or sort by a column you declared `type: :password` or `type: :hidden`, give it another type, or search it from your own code. Listing it in `searchable` no longer makes it searchable.
- If a system that reads your exports expects a password or token column, export that value from your own code. If it expects a `:hidden` column, list that column in `export_fields`.

### 21. Exports honour the `exports` DSL

In 0.6.0, `exports :csv` and a bare `exports` had no effect: every resource served both CSV and JSON. Now a format the resource does not enable returns `404`, and a bare `exports` turns exports off.

**Action required:** If a resource declares `exports` and something downloads a format it does not list, add that format (for example `exports :csv, :json`).

### 22. Export columns and rows

- Columns follow the order of `export_fields`. In 0.6.0 they followed the table's column order.
- CSV rows follow the index sort (`sort`/`direction`, or `config.default_sort`), as JSON already did. ActiveRecord's `find_each` dropped the `ORDER BY`, so CSV rows came out in primary-key order. The ActiveRecord adapter now pages an ordered scope with `LIMIT`/`OFFSET` plus a primary-key tiebreak.
- `:file` and `:files` fields export filenames (for `:files`, a JSON array or a comma-separated CSV cell), and are blank when nothing is attached. In 0.6.0 they exported an object inspect string.
- `:rich_text` fields export the stored HTML. In 0.6.0 they exported the content rendered through the ActionText layout, wrapped in `<div class="trix-content">` and, in development, surrounded by comments with template paths on the server.

**Action required:** Update consumers that read export columns by position. A custom adapter's `find_each(scope)` must keep the scope's order, or CSV exports from that adapter ignore the sort (see `find_each` in the [custom adapters guide](docs/guides/custom-adapters.md)).

### 23. Declared and inferred filters

- A filter declared with `filter` replaces the auto-inferred filter of the same name. In 0.6.0, `filter :status, type: :select` on an enum column rendered two Status selects, and the first one, the inferred filter, did nothing. The declared filter now renders at its declared position, after the inferred filters, instead of the inferred one at the front of the list. A declared `:select` without `options` offers the enum values, and one with `options` offers only those (in 0.6.0 an enum column always listed every enum value).
- `remove_filter :name` also removes an auto-inferred filter. In 0.6.0 it only removed declared filters.

**Action required:** Update system specs that pick the first of two filters with the same label, or that depend on the position of a declared enum filter. Check `remove_filter` calls: the inferred filter they name now disappears.

### 24. Index page: URL, sort, filters and bulk actions

- The `records` Turbo frame has `data-turbo-action="advance"`, so links and forms inside it that do not target `_top`, such as pagination, update the address bar and push a history entry.
- Column-header sort links keep the active filters, go back to page 1, and load the whole page (`data-turbo-frame="_top"`).
- The `base_url` passed to a `table` override now includes the active filters, besides the scope and search query. It never includes `sort`, `direction` or `page`.
- The `hidden_params` passed to a `search` override now include `sort` and `direction` when they are set. The built-in search form, filter form and Clear link keep the sort too.
- The bulk-actions form has hidden fields `scope`, `q`, `sort`, `direction`, `page` and `filters[...]`, and submits to the whole page (`data-turbo-frame="_top"`). After a bulk action, the redirect returns to that index state, with the page capped at the list's new last page when the action emptied the page it ran from. Bulk action blocks still receive only the records and the form params.
- An index request whose `page` is past the last page now answers with a `302` to the last page, keeping `scope`, `q`, `sort`, `direction` and `filters`. Before, it rendered `200` with an empty list and no pagination.

**Action required:**

- In a custom `table` component, keep appending `sort=` and `direction=` to `base_url`, and give sort links `data-turbo-frame="_top"`, as the built-in table and `DataTableComponent` do. Otherwise the search and filter forms, which sit outside the `records` frame, keep the old sort.
- In a custom `search` component, render every `hidden_params` entry as a hidden field. The keys are flat field names such as `filters[title][op]`.
- Update specs that expect a sort click to drop the filters, a bulk action to redirect to the bare index URL, or a page past the last one to answer `200`.

### 25. Show page: member actions, related lists and confirmations

- The Actions card lists only the member actions `execute_action` would run: allowed by the resource policy, able to load the record (see section 8), and with a passing `condition`. The card is not rendered when no action is left. Before, actions the policy denied were shown and answered `403`.
- has_many related lists are rendered by `IronAdmin::Resources::RelatedListComponent`. The table sits in an `overflow-x-auto` container, the card has no border, rows are divided with `theme.table_border`, and "View all" is localized (`iron_admin.resources.show.view_all`). "View all" opens the associated index filtered by the parent's foreign key when the associated resource has a filter on that column.
- A resource action's `confirm_message` is used in its confirmation dialog. Without one, the dialog shows `iron_admin.resources.action.confirm`; `iron_admin.resources.show.delete_confirm` is only used for Delete.
- Action forms and bulk action forms submit with `data-turbo-frame="_top"`, so after Execute the browser lands on the redirect target and shows its flash message.

**Action required:**

- If you override `app/views/iron_admin/resources/show.html.haml`, loop over `@member_actions` instead of `@resource_class.defined_actions` to get the same filtering, and use `@record_reachable` for the Edit button (it is false for a soft-deleted record that edit cannot load). An override copied from 0.6.0 still renders, without the filtering. `@edit_reachable` only existed in unreleased 0.7.0 code and is gone.
- To make "View all" open a filtered list, declare a filter on the foreign key in the associated resource, for example `filter :user_id, type: :select` in `LicenseResource`.
- If you translated `iron_admin.resources.show.delete_confirm` to change the text of custom action dialogs, move that text to `iron_admin.resources.action.confirm` or to each action's `confirm_message`.
- Update system specs that expect a button for an action the policy denies.

### 26. Imports

Imports can now be completed from the UI:

- The upload form posts with `data-turbo="false"`. The preview is rendered in reply to that POST, and Turbo Drive discarded it ("Form responses must redirect to another location").
- The preview page has an "Import N rows" button. It posts the previewed file back to `POST /admin/:resource_name/import` (multipart) in the hidden fields `import_format` and `import_data` (Base64), so the file is not uploaded again.
- The preview validates a row that matches an existing record on `import_upsert_key` against that record, as the import does, shows plain cell values (`IronAdmin::Import::ImportPreview#cell_text`; dates and times use the show page's default formats, with no locale lookup), and pluralizes the row count.
- `import_options max_rows:` (default 5,000) is also checked at the preview step: a larger file is rejected with "Import contains N rows, exceeding the M row limit".
- The upload form lists the importable fields, and the preview shows its columns, in the order of `import_fields`. In 0.6.0 the list followed the table's column order and the preview followed the file's headers. `importable_fields` and `IronAdmin::Import::ColumnMapper#map_headers` return that order too.
- The `file` param must be a multipart upload. A plain string is ignored; in 0.6.0 it was read as a path on the server.
- A row whose save fails without validation errors (a model callback that throws `:abort`, or an HTTP adapter that cannot reach the API) is counted as failed with "The record could not be saved." (`iron_admin.imports.errors.not_saved`). In 0.6.0 it was counted as created or updated.

The confirm step carries the file in a form field, which Base64 makes about 33% larger. Rack 3.1 and later count non-file multipart fields against `RACK_MULTIPART_BUFFERED_UPLOAD_BYTESIZE_LIMIT` (16 MiB by default), so the preview rejects files larger than 12 MB with "The file is larger than 12 MB. Split it into smaller files." (`iron_admin.imports.errors.file_too_large`) instead of showing an Import button that fails with a server error. The 12 MB limit does not follow the Rack variable.

**Action required:**

- If you override `app/views/iron_admin/imports/new.html.haml`, add `data: { turbo: false }` to the upload `form_tag`, or Turbo Drive discards the preview again.
- If you override `app/views/iron_admin/imports/preview.html.haml`, add a form that POSTs to `resource_import_path(@resource_class.resource_name)` with `multipart: true` and the hidden fields `import_format` (`@import_format`) and `import_data` (`@import_data`), or the page has no Import button. `@preview.cell_text(row, field_name)` returns the text of a cell.
- If you translate `iron_admin.imports.preview.summary`, give it `one` and `other` forms, and add `iron_admin.imports.preview.import_button` ("Import %{count} row" / "Import %{count} rows"). A plain string `summary` keeps working but does not pluralize.
- To import a file larger than 12 MB, split it, or run `IronAdmin::Import::Importer` from Ruby (see the [imports guide](docs/guides/imports.md)).

### 27. Forms: field order and color fields

- New and edit forms render fields in the order given to `form_fields`. In 0.6.0 they came in database column order. Names that resolve to no field (for example a has_many such as `:comments`) are still ignored.
- A `:color` field renders a color picker without a `name` (id `record_<field>_picker`, `aria-label` "<Field> picker") and a hex text input, which is the only one submitted as `record[<field>]`. The text input only accepts `#rgb` or `#rrggbb` (pattern `#(?:[0-9a-fA-F]{3}){1,2}`) and shows `iron_admin.fields.color_invalid` otherwise. The new `cp-color-field` Stimulus controller keeps the two in sync. Without JavaScript the text input still works, and the picker only shows the color. In 0.6.0 both inputs were submitted and the text input always won, so a color picked with the swatch was lost.

**Action required:**

- Check that each `form_fields` list is in the order you want the form to show.
- If a `:color` column stores other CSS color formats (names such as `red`, `rgb(...)`, or `#rrggbbaa`), the browser now blocks the form until the value is a `#rgb` or `#rrggbb` color. Use `type: :text` or a custom field type for those columns.
- Update system specs that find the color picker by its `record[<field>]` name. The picker has no name now; set the color through the hex text input.

### 28. Dashboard recent tables

- A `recent` table whose `scope:` has no `order` (or that has no `scope:`) lists the newest records first: `created_at` descending, then the primary key descending, or the primary key alone when there is no `created_at`. A scope with its own `order(...)` keeps its order.
- The columns are the resource's `index_fields` when it declares them. Otherwise they are the id, the label column (`name`, `title`, `email`, `label` or `slug`), other short columns, and `created_at`, four at most, instead of the first four database columns. Long or sensitive types (textarea, rich_text, markdown, json, password, ...) are skipped, and fields hidden from the current user are left out.
- `IronAdmin::Dashboards::RecentTableComponent.new` takes an optional `current_user:`. The dashboard passes it.
- A `recent` table is not rendered when the current user may not read the resource (`deny :read`, a conditional `allow :read`, or `deny_actions :read`), and `config.tenant_scope` applies to it after its `scope:`. Before, the dashboard listed the newest records of a resource the user could not read, across tenants.

**Action required:** Declare `index_fields` on a resource to choose its dashboard columns. If you render `RecentTableComponent` yourself, pass `current_user:`; without it, `visible:` procs receive `nil`. Check that each role sees the dashboard tables it should: a table for a resource the role cannot read is gone.

### 29. Translations and import map entries

New keys in IronAdmin's `en.yml`:

| Key | English text |
|-----|--------------|
| `iron_admin.errors.forbidden.title` / `.message` | "Not authorized" / "You don't have permission to view this page or perform this action." |
| `iron_admin.errors.not_found.title` / `.message` | "Page not found" / "This page doesn't exist, or the record was removed." |
| `iron_admin.errors.back_to_resource` | "Back to %{resource}" |
| `iron_admin.errors.back_to_dashboard` | "Back to dashboard" |
| `iron_admin.alerts.dismiss` | "Dismiss" |
| `iron_admin.resources.action.confirm` | "Are you sure?" |
| `iron_admin.imports.preview.import_button` | `one`: "Import %{count} row", `other`: "Import %{count} rows" |
| `iron_admin.imports.errors.file_too_large` | "The file is larger than %{size}. Split it into smaller files." |
| `iron_admin.imports.errors.not_saved` | "The record could not be saved." |
| `iron_admin.fields.boolean_true` / `boolean_false` | "Yes" / "No" |
| `iron_admin.fields.color_picker_label` | "%{field} picker" |
| `iron_admin.fields.color_invalid` | "Enter a hex color such as #1a2b3c or #abc." |
| `iron_admin.fields.polymorphic_record_label` | "%{field} record" |
| `iron_admin.resources.index.search_label` | "Search %{resource}" |
| `iron_admin.resources.index.select_all` / `select_record` | "Select all" / "Select %{record}" |
| `iron_admin.filters.from_label` / `to_label` | "%{filter} from" / "%{filter} to" |
| `iron_admin.filters.operator_label` | "%{filter} operator" |
| `iron_admin.filters.upper_value_label` | "%{filter} upper value" |

`iron_admin.imports.preview.summary` is now a plural hash (`one`: "%{count} row detected.", `other`: "%{count} rows detected.").

The engine import map pins two new Stimulus controllers, `iron_admin/controllers/cp_alert_controller` and `iron_admin/controllers/cp_color_field_controller`, and `iron_admin/index.js` registers them as `cp-alert` and `cp-color-field`.

**Action required:** If your app ships its own IronAdmin translations (another locale, or overrides of the English texts), add the new keys and the plural forms of `summary`. If you pin IronAdmin's JavaScript in your own import map, or register its Stimulus controllers yourself instead of importing `iron_admin`, add both controllers. The engine layout's `import "iron_admin"` already registers them.

### 30. Form, filter and bulk-select control names

Every control of the built-in forms, filter panel, search box and bulk-select column now has an accessible name, and every label points at an existing control. Some ids and elements changed:

- Field labels point at the control: `record_<foreign_key>` for a `belongs_to` select or autocomplete, `record_<type_column>` for a polymorphic `belongs_to` (its record select has `aria-label` "<Field> record"), and `record_<field>` for the text input of a `:tags` field. Nested-form row labels are `<label for>` elements pointing at `record_<association>_attributes_<index>_<field>`.
- The field name of a `:radio` or `:boolean_group` field is a `<span id="record_<field>_label">`, and the association name above has_many checkboxes a `<span id="record_<singular>_ids_label">`, instead of a `<label>`. Each names the `role="radiogroup"` or `role="group"` container of the choices. has_many checkboxes have the ids `record_<singular>_ids_<id>` instead of all sharing `record_<singular>_ids_`.
- The "Remove" checkbox of an attached `:file` field has the id `record_<field>_purge` (it was `<field>_purge`). Its name, `record[<field>_purge]`, is unchanged.
- The autocomplete text input has the id `record_<foreign_key>` in the form (it was `autocomplete-<hex>-input`), `role="combobox"` and `aria-expanded`, and its results are `role="option"` items of a `role="listbox"`. `BelongsToAutocompleteComponent.new` takes an optional `input_id:`; without it the input keeps the `<component_id>-input` id.
- Filter panel controls have ids: `filters_<name>` for select and boolean filters, `filters_<name>_op` for operator selects, and the existing `filters_<name>_value`, `_value_2`, `_from` and `_to` inputs. `Filters::SelectFilterComponent` gives its select `filters_<name>` and `Filters::DateRangeComponent` its inputs `filters_<name>_from` / `_to`. The hidden `q` and `scope` fields of the filter panel and `Filters::BarComponent`, and the hidden fields of `Filters::SearchComponent`, have no id any more.
- The search box has `aria-label` "Search <resource label>". `Filters::SearchComponent` accepts `resource_class:` (the `search` slot passes it when `initialize` declares it) and otherwise uses its placeholder as the name.
- Bulk-select checkboxes have `aria-label` "Select all" and "Select <record label>".
- The audit log filter controls and buttons carry `h-10.5`, and its date inputs use the same padding as the selects (`cp_input_class`).

**Action required:**

- Update system specs that find controls by the old ids (`autocomplete-…-input`, `<field>_purge`, `record_<singular>_ids_`) or that expect a `<label>` for the field name of radio, boolean group or has_many choices. Specs can now find controls by their label, for example `select "ada@example.com", from: "User"`, and, with `Capybara.enable_aria_label = true`, by their `aria-label`, for example `check "Select all"`.
- In a `search` or `table` override, render hidden fields without ids and name the search input and the bulk-select checkboxes (see the [components guide](docs/guides/components.md)). A field input override must give its input the id `form.field_id(field.name)` for the field label to point at it.
- If your app ships its own IronAdmin translations, add the keys listed in section 29.

## What does NOT change

- **Resource, dashboard, tool, and policy DSL** — No DSL method was removed or renamed. `Resource.component` now validates its slot (section 15), `exports` is enforced (section 21), and `remove_filter` also removes inferred filters (section 23).
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
