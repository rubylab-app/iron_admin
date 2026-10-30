# Extending the Engine

IronAdmin is designed to be extended at every level.

## Extension Points

1. **Configuration blocks** - Authentication, current user, audit logging
2. **Resource DSL** - Fields, filters, scopes, actions, policies
3. **Component overrides** - Replace the shell, navbar, sidebar, flash messages, index table, form, filter bar, search box or a field type's form input with your own ViewComponent (see [Components](components.md#overriding-components))
4. **Custom field types** - Register new field renderers
5. **Dashboard customization** - Metrics, charts, recent records
6. **Theme system** - Named themes with 96 properties, picked per request
7. **Route mounting** - Mount at any path

## MongoDB / Mongoid Support

IronAdmin supports MongoDB via the built-in Mongoid adapter. Add `mongoid` to your Gemfile and configure resources:

```ruby
# Gemfile
gem "mongoid"

# app/iron_admin/resources/article_resource.rb
module IronAdmin
  module Resources
    class ArticleResource < IronAdmin::Resource
      self.adapter_class = :mongoid
    end
  end
end
```

The Mongoid adapter:
- Maps Mongoid field types to IronAdmin field types automatically
- Supports `embeds_many`/`embeds_one` associations (mapped to `:has_many`/`:has_one`)
- Uses `$regex` for case-insensitive search
- Provides a `MongoidQueryBuilder` for operator-based string/number filters
- Falls back gracefully for MongoDB standalone (transactions require replica set)

You can mix adapters in the same app — some resources using ActiveRecord, others using Mongoid.

## HTTP REST API Support

IronAdmin can manage resources from external REST APIs. Add `faraday` to your Gemfile:

```ruby
# Gemfile
gem "faraday"

# config/initializers/iron_admin.rb
IronAdmin.configure do |config|
  config.http_base_url = "https://api.example.com/v1"
  config.http_headers = { "Authorization" => "Bearer #{ENV['API_TOKEN']}" }
end

# app/iron_admin/resources/product_resource.rb
module IronAdmin
  module Resources
    class ProductResource < IronAdmin::Resource
      self.adapter_class = :http

      # Fields auto-discovered from API response. Just customize:
      field :status, type: :badge
      searchable :name
    end
  end
end
```

The HTTP adapter:
- Each counted scope sends one more unpaginated list request on every index view, even when the response has no `meta.total`. Without `meta.total` the tab shows its name and no number. Set `scope_counts false` on an HTTP resource whose API returns no total.
- Auto-discovers fields from the first API response (convention-over-configuration)
- Infers resource path from name (`ProductResource` → `GET /products`)
- Full CRUD via standard REST verbs
- Lazy query execution (no HTTP requests until records are accessed)
- Populates `record.errors` from API 422 responses for form validation
- **Does not require a Ruby model class.** When `adapter_class = :http`, `Resource.model` returns `IronAdmin::Adapters::Http::ModelProxy` — a thin wrapper exposing `model_name.plural` / `model_name.human` for routing and labels, and an empty `column_names` (HTTP resources have no static schema). Fields are discovered from the API response at request time.

## Custom Resources with Business Logic

```ruby
module IronAdmin
  module Resources
    class SubscriptionResource < IronAdmin::Resource
      action :cancel, icon: "x-circle", confirm: true do |record|
        Billing::CancelSubscriptionService.call(subscription: record)
      end

      bulk_action :pause_all do |records|
        records.each { |sub| sub.update!(status: :paused) }
      end
    end
  end
end
```

## Subclassing the Base Controller

Assigning `Time.zone` leaves that zone on the thread, so the next request served
by the same Puma thread renders in the previous admin user's zone. `Time.zone = ""`
raises `ArgumentError`. `ActiveSupport::TimeZone[nil]` raises `ArgumentError` too,
so a missing user or a nil zone returns 500 if it is passed straight in.

Scope the request with `around_action` and `Time.use_zone`. Stringify the name
first: a blank or unknown name makes `ActiveSupport::TimeZone[]` return nil, and
the callback then uses `Time.zone_default`. `Time.use_zone` restores the previous
zone when the action returns. `to_prepare` runs again when the controller class
is reloaded, and installs the callback on the reloaded class.

```ruby
# config/initializers/iron_admin.rb
Rails.application.config.to_prepare do
  IronAdmin::ApplicationController.class_eval do
    around_action :switch_iron_admin_time_zone

    private

    def switch_iron_admin_time_zone(&action)
      name = iron_admin_current_user&.timezone
      zone = ActiveSupport::TimeZone[name.to_s] || Time.zone_default
      Time.use_zone(zone, &action)
    end
  end
end
```

## Adding Custom Routes

```ruby
mount IronAdmin::Engine => "/admin"

namespace :admin do
  get "reports/revenue", to: "reports#revenue"
end
```

## Overriding Views

Place overrides following the engine's view path:

```
app/views/iron_admin/
  resources/
    index.html.haml
  dashboard/
    index.html.haml
app/views/layouts/iron_admin/
  application.html.haml
  minimal.html.haml
  _document_head.html.haml
```

Rails uses your app's views over the engine's views automatically. Layouts live under
`app/views/layouts`, not under `app/views/iron_admin`.

An override replaces the engine's markup, so copy it from the IronAdmin version you run and
keep what the controllers rely on:

- `iron_admin/shared/error.html.haml` is the page for HTML `403` and `404` responses. It
  receives only the local `error` (`:forbidden` or `:not_found`). Policy denials and 404s
  render it inside the admin layout (`layouts/iron_admin/application`), with `@resource_class`
  set when the URL named a registered resource. An `authenticate` block whose value is `false`
  renders it in `layouts/iron_admin/minimal`, with `iron_admin_error_navigation?` false and no
  `@resource_class`. Links into the admin and policy calls belong behind that helper.
- `iron_admin/resources/show.html.haml`: loop over `@member_actions` (the member actions the
  controller would run for this record) rather than `@resource_class.defined_actions`, and
  show the Edit button only when `@record_reachable` is true.
- `iron_admin/resources/index.html.haml`: render the bulk bar and the row checkboxes from
  `@permitted_bulk_actions`. When that list is empty, render neither. Pass
  `authenticity_token: form_authenticity_token` to the bulk `form_tag`.
- `iron_admin/imports/new.html.haml`: the upload form needs `data: { turbo: false }`.
- `iron_admin/imports/preview.html.haml`: keep the import form that posts `import_format`
  and `import_data` back to `resource_import_path`. See the [imports guide](imports.md).

## Extending the Resource Class

A subclass of `IronAdmin::Resource` is registered as a resource. `ApplicationResource`
is registered as "applications", and every admin page that renders the sidebar then
raises `uninitialized constant Application` while building that resource's model.
Share the behavior with a module. A module is not a resource, so it is not registered.

```ruby
# app/iron_admin/resources/shared_resource.rb
module IronAdmin
  module Resources
    module SharedResource
      def self.included(resource_class)
        resource_class.exports :csv, :json
        resource_class.menu group: "General" unless resource_class.menu_options[:group]
      end
    end
  end
end
```

`menu` replaces the whole options hash. When a resource sets its own menu, repeat `group:`:

```ruby
# app/iron_admin/resources/user_resource.rb
module IronAdmin
  module Resources
    class UserResource < IronAdmin::Resource
      include SharedResource

      menu icon: "users", group: "People"
    end
  end
end
```

## Per-Environment Configuration

```ruby
IronAdmin.configure do |config|
  config.title = "My App Admin"
  config.title += " [STAGING]" if Rails.env.staging?
  config.per_page = Rails.env.development? ? 10 : 25
end
```

## Custom Field Types API

The `FieldTypeRegistry` allows you to register custom field types that integrate with IronAdmin's display and form rendering.

### Registering a Custom Field Type

The form input is a component override. Assign a String to `config.components.fields`:
it is stored as that String and constantized when the form renders, so the next
request uses the reloaded class. The [components guide](components.md#field-input-overrides)
documents the override. It wins over `form_component`, and it does not change the
show or index pages.

Register `display` and `index_display` once, from the initializer, and do not call
a reloadable constant from those blocks. `IronAdmin.register_field_type` calls
`FieldTypeRegistry.register`. The registry is not cleared on reload and raises
`ArgumentError` (`Field type :star_rating is already registered`) on a second register.

Do not pass the component to `form_component`. Rails 8 does not autoload constants
while initializers run, so `form_component MyApp::StarRatingComponent` raises
`NameError` (`uninitialized constant MyApp`) at boot. `form_component` stores the
class. A String raises `NoMethodError` (`undefined method 'new' for an instance of String`)
when the form renders. A class captured at boot stays that class after a reload, and
breaks as soon as it calls a sibling constant that has been reloaded.

```ruby
# config/initializers/iron_admin.rb
IronAdmin.configure do |config|
  config.components.fields[:star_rating] = "MyApp::StarRatingComponent"
end

IronAdmin.register_field_type(:star_rating) do
  display do |record, field|
    value = record.public_send(field.name)
    value.to_i.clamp(0, 5).times.map { "&#9733;" }.join.html_safe
  end

  index_display do |record, field|
    "#{record.public_send(field.name)}/5"
  end
end
```

The display block draws one character per unit of the stored value and does not
stop. Clamp it. The input's `max` is checked only by the browser. Reject a value
outside the scale on the model: `validates :rating, inclusion: { in: 1..5 }`.

The component takes `form:`, `field:` and `record:`. `StarScale` is defined in the
same file, so loading the component defines it. The String above is constantized
on each render, which picks up the reloaded component and that sibling.

```ruby
# app/components/my_app/star_rating_component.rb
module MyApp
  module StarScale
    def self.max
      5
    end
  end

  class StarRatingComponent < ViewComponent::Base
    def initialize(form:, field:, record:)
      super()
      @form = form
      @field = field
      @record = record
    end

    def call
      @form.number_field(@field.name, min: 1, max: StarScale.max)
    end
  end
end
```

A partial is the other form option: `form_partial "shared/star_rating_input"`.

### Using a Custom Field Type

```ruby
# app/iron_admin/resources/review_resource.rb
module IronAdmin
  module Resources
    class ReviewResource < IronAdmin::Resource
      field :rating, type: :star_rating
    end
  end
end
```

### API Reference

| Method | Description |
|--------|-------------|
| `display { \|record, field\| ... }` | Block that returns HTML for the show page. Do not call a reloadable constant from it. |
| `index_display { \|record, field\| ... }` | Block that returns HTML for the index table cell. Falls back to `display`. |
| `form_component(klass)` | Stores a component class for the form. A String has no `new`, and a class captured at boot stays stale after a reload. Use `config.components.fields` with a class name instead. |
| `form_partial(path)` | Partial path to render on forms |

The `FieldTypeRegistry` raises `ArgumentError` if you attempt to register a type name that is already registered. Use `FieldTypeRegistry.registered?(:type_name)` to check before registering.

## Custom Tools

Custom tools let you add standalone pages to the admin panel with full sidebar integration.

### Creating a Tool

Create a tool class that inherits from `IronAdmin::Tool`:

```ruby
# app/iron_admin/tools/report_tool.rb
module IronAdmin
  module Tools
    class ReportTool < IronAdmin::Tool
      menu label: "Reports", icon: "chart-bar", priority: 1, group: "Analytics"
    end
  end
end
```

Tools auto-register with `ToolRegistry` via the `inherited` callback, similar to how resources auto-register with `ResourceRegistry`.

### Tool Views

Create a view template for your tool at:

```
app/views/iron_admin/tools/<tool_name>/show.html.erb
```

For example, `IronAdmin::Tools::ReportTool` (which has `tool_name` of `"report"`) would use:

```
app/views/iron_admin/tools/report/show.html.erb
```

### Tool Routes

Tools are automatically routed at `/admin/tools/:tool_name`:

| Route | Controller Action | Description |
|-------|-------------------|-------------|
| `GET /admin/tools/:tool_name` | `tools#show` | Render the tool's show view |
| `POST /admin/tools/:tool_name/:action_name` | `tools#execute` | Execute a tool action |

### Declarative Tool Actions

Use `tool_action` to declare actions with metadata, form fields, and authorization:

```ruby
# app/iron_admin/tools/cache_manager_tool.rb
module IronAdmin
  module Tools
    class CacheManagerTool < IronAdmin::Tool
      menu label: "Cache Manager", icon: "server", group: "System"

      tool_action :flush_all,
        label: "Flush All Caches",
        icon: "trash",
        confirm: true,
        condition: ->(user) { user&.admin? }

      tool_action :flush_key,
        label: "Flush Specific Key",
        form_fields: [
          { name: :cache_key, type: :text, required: true, placeholder: "e.g. users/123" }
        ]

      def flush_all(ctx)
        Rails.cache.clear
        ctx.flash[:notice] = "All caches flushed"
      end

      def flush_key(ctx)
        key = ctx.action_params(:cache_key)[:cache_key]
        Rails.cache.delete(key)
        ctx.flash[:notice] = "Key '#{key}' flushed"
      end
    end
  end
end
```

**ToolContext** is injected into 1-arg methods and provides:
- `ctx.params` — raw request params
- `ctx.current_user` — the current admin user
- `ctx.flash` — flash messages, shown at the top of the page after the redirect
- `ctx.action_params(:key1, :key2)` — safe param extraction (strong params)

**Flash messages:** the admin shell shows `ctx.flash[:notice]` and `ctx.flash[:success]` as
success alerts, `ctx.flash[:alert]` and `ctx.flash[:error]` as error alerts, and
`ctx.flash[:warning]` and `ctx.flash[:info]` as warning and info alerts. Other keys are not
shown. See [Flash Messages](components.md#flash-messages).

**Authorization:** The `condition:` proc receives the current user. If it returns false, the action returns 403 (an error page for browser requests) and is hidden from the UI.

**Form fields:** Actions with `form_fields:` render a form page before execution. Supported types: `:text`, `:textarea`, `:number`, `:boolean`, `:date`, `:datetime`, `:select`.

Declare every action the tool should run with `tool_action`. A tool is affected when it, or any tool it inherits from, declares at least one action: it only dispatches those names. `POST /admin/tools/:tool/:action` to any other name, including a public method defined on a subclass, returns 404 and does not call the method. A declared action also appears as a button on the default tool page. Make helpers that are not actions `private`.

A tool that declares no `tool_action`, and inherits none, still dispatches its own public methods. That fallback is deprecated and removed in 1.0. Each dispatch warns once per tool class and method through `IronAdmin.deprecator` (registered as `:iron_admin` on `Rails.application.deprecators`). Declare those methods with `tool_action` before 1.0. Set `strict_tool_actions` inside `IronAdmin.configure` to turn the fallback off for every tool (default `false`); undeclared names then return 404:

```ruby
IronAdmin.configure do |config|
  config.strict_tool_actions = true
end
```

### Menu Options

| Option | Type | Description |
|--------|------|-------------|
| `label` | String | Display name in the sidebar |
| `icon` | String | Heroicon name |
| `priority` | Integer | Sort order (lower = higher in sidebar) |
| `group` | String | Sidebar group heading (defaults to "Tools") |

### Tool Routes

| Route | Controller Action | Description |
|-------|-------------------|-------------|
| `GET /admin/tools/:tool_name` | `tools#show` | Render the tool's show view |
| `GET /admin/tools/:tool_name/:action_name/form` | `tools#action_form` | Render action form |
| `POST /admin/tools/:tool_name/:action_name` | `tools#execute` | Execute a tool action |

### ToolRegistry API

| Method | Description |
|--------|-------------|
| `ToolRegistry.all` | Returns all registered tool classes |
| `ToolRegistry.find(tool_name)` | Find a tool by its name |
| `ToolRegistry.grouped` | Tools grouped by their `menu_options[:group]` |
| `ToolRegistry.sorted` | Tools sorted by `menu_options[:priority]` |
| `ToolRegistry.reset!` | Clear all registered tools (useful in tests) |

## i18n / Localization

IronAdmin ships with full i18n support. All UI strings are externalized using `I18n.t()` calls.

### Default Locale File

IronAdmin includes a default English locale file at `config/locales/en.yml` under the `iron_admin:` namespace. The engine automatically loads this file.

### Key Structure

```yaml
en:
  iron_admin:
    resources:
      create:
        success: "%{model} created."
      update:
        success: "%{model} updated."
      destroy:
        success: "%{model} deleted."
      index:
        new_button: "New %{model}"
        search_placeholder: "Search..."
        empty_state: "No records found."
      # ... more keys
    fields:
      select_placeholder: "Select..."
      url_placeholder: "https://"
      email_placeholder: "user@example.com"
      # ... more keys
    form:
      cancel_button: "Cancel"
    navigation:
      dashboard: "Dashboard"
    filters:
      "true": "Yes"
      "false": "No"
```

Some keys are pluralized hashes with `one` and `other` forms, such as
`imports.preview.summary` ("%{count} rows detected.") and `imports.preview.import_button`
("Import %{count} rows"). Give every plural form your locale needs.

### Keys Added in 0.7.0

If you ship your own IronAdmin translations, add these keys, all under `iron_admin.`:

| Key | Used for |
|-----|----------|
| `errors.forbidden.title`, `errors.forbidden.message` | The 403 page ("Not authorized") |
| `errors.not_found.title`, `errors.not_found.message` | The 404 page ("Page not found") |
| `errors.back_to_resource` | Error page link to the index ("Back to %{resource}") |
| `errors.back_to_dashboard` | Error page link to the dashboard ("Back to dashboard") |
| `alerts.dismiss` | Accessible label of the alert close button ("Dismiss") |
| `resources.action.confirm` | Confirmation of actions without `confirm_message` ("Are you sure?") |
| `imports.preview.import_button` | Import button on the preview page (`one`/`other`) |
| `fields.boolean_true`, `fields.boolean_false` | Screen reader text of boolean icons ("Yes", "No") |
| `fields.color_picker_label` | Accessible label of the color picker ("%{field} picker") |
| `fields.color_invalid` | Hint for a color that is not a hex color |

`imports.preview.summary` became a plural hash in 0.7.0. A plain string still works but is
not pluralized.

### Adding Translations

To add a new language, create a locale file following the same key structure:

```yaml
# config/locales/iron_admin.es.yml
es:
  iron_admin:
    resources:
      create:
        success: "%{model} creado."
      update:
        success: "%{model} actualizado."
      destroy:
        success: "%{model} eliminado."
      index:
        new_button: "Nuevo %{model}"
        search_placeholder: "Buscar..."
        empty_state: "No se encontraron registros."
    fields:
      select_placeholder: "Seleccionar..."
    form:
      cancel_button: "Cancelar"
    navigation:
      dashboard: "Panel"
```

Place the file in your host app's `config/locales/` directory. Rails will automatically pick it up when the corresponding locale is set.

### Setting the Locale

IronAdmin uses the standard Rails `I18n.locale`. There is no `config.before_action`
(`NoMethodError` at boot). Controllers inherit from `ActionController::Base`, so a
`before_action` in the host `ApplicationController` does not run here either.

Assigning `I18n.locale` leaves that locale on the thread, so the next request
served by the same Puma thread renders in the admin user's locale. A blank or
unavailable locale raises `I18n::InvalidLocale` (Rails enforces available locales
by default) and the request returns 500.

Scope the request with `around_action` and `I18n.with_locale`.
`I18n.locale_available?` is false for a blank or unknown locale, and the callback
then uses `I18n.default_locale`. The current user is expected to respond to
`locale` with a value `I18n` considers available, such as a Symbol listed in
`I18n.available_locales`. `I18n.with_locale` restores the previous locale when the
action returns. `to_prepare` runs again when the controller class is reloaded, and
installs the callback on the reloaded class. Responses rendered by `rescue_from`
(the 404 and the 400) and the authentication-denied page still use the default
locale: `rescue_from` runs after this callback restores it, and
`authenticate_iron_admin_user!` is a `before_action` that runs first and stops
the chain. `prepend_around_action` would wrap that `before_action`, so the denied
page would use the user's locale; the `rescue_from` pages would still use the default.

```ruby
# config/initializers/iron_admin.rb
Rails.application.config.to_prepare do
  IronAdmin::ApplicationController.class_eval do
    around_action :switch_iron_admin_locale

    private

    def switch_iron_admin_locale(&action)
      locale = iron_admin_current_user&.locale
      locale = I18n.default_locale unless I18n.locale_available?(locale)
      I18n.with_locale(locale, &action)
    end
  end
end
```

## Custom Adapters

IronAdmin uses an adapter pattern to decouple from any specific ORM. It ships with `ActiveRecord` and `Mongoid` adapters, but you can create adapters for any data source (Sequel, HTTP APIs, DynamoDB, etc.).

See the [Building a Custom Adapter](custom-adapters.md) guide for the complete reference, including all 35 methods, duck type contracts, QueryBuilder integration, and testing patterns.

## Testing Resources

```ruby
RSpec.describe IronAdmin::Resources::UserResource do
  it "maps to the User model" do
    expect(described_class.model).to eq(User)
  end

  it "resolves fields from the schema" do
    names = described_class.resolved_fields.map(&:name)
    expect(names).to include(:email, :name)
  end
end
```
