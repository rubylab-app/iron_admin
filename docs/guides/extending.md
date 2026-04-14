# Extending the Engine

IronAdmin is designed to be extended at every level.

## Extension Points

1. **Configuration blocks** - Authentication, current user, audit logging
2. **Resource DSL** - Fields, filters, scopes, actions, policies
3. **Component overrides** - Replace any UI component
4. **Custom field types** - Register new field renderers
5. **Dashboard customization** - Metrics, charts, recent records
6. **Theme system** - 40+ CSS class properties
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

## Custom Resources with Business Logic

```ruby
class SubscriptionResource < IronAdmin::Resource
  action :cancel, icon: "x-circle", confirm: true do |record|
    Billing::CancelSubscriptionService.call(subscription: record)
  end

  bulk_action :pause_all do |records|
    records.each { |sub| sub.update!(status: :paused) }
  end
end
```

## Subclassing the Base Controller

```ruby
# config/initializers/iron_admin.rb
Rails.application.config.to_prepare do
  IronAdmin::ApplicationController.class_eval do
    before_action :set_timezone

    private

    def set_timezone
      Time.zone = iron_admin_current_user&.timezone || "UTC"
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
  layouts/
    application.html.haml
```

Rails uses your app's views over the engine's views automatically.

## Extending the Resource Class

```ruby
class ApplicationResource < IronAdmin::Resource
  exports :csv, :json

  def self.inherited(subclass)
    super
    subclass.menu group: "General" unless subclass.menu_options[:group]
  end
end

class UserResource < ApplicationResource
  menu group: "People"
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

```ruby
# config/initializers/iron_admin.rb
IronAdmin::FieldTypeRegistry.register(:star_rating) do
  # Required: how to display on show pages
  display do |record, field|
    value = record.public_send(field.name)
    value.to_i.times.map { "&#9733;" }.join.html_safe
  end

  # Optional: how to display on index pages (falls back to display if omitted)
  index_display do |record, field|
    value = record.public_send(field.name)
    "#{value}/5"
  end

  # Optional: ViewComponent class for the form input
  form_component MyApp::StarRatingComponent

  # Or use a partial path instead of a component:
  # form_partial "shared/star_rating_input"
end
```

### Using a Custom Field Type

```ruby
class ReviewResource < IronAdmin::Resource
  field :rating, type: :star_rating
end
```

### API Reference

| Method | Description |
|--------|-------------|
| `display { \|record, field\| ... }` | Block that returns HTML for the show page |
| `index_display { \|record, field\| ... }` | Block that returns HTML for the index table cell |
| `form_component(klass)` | ViewComponent class to render on forms |
| `form_partial(path)` | Partial path to render on forms (alternative to `form_component`) |

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
- `ctx.flash` — flash messages
- `ctx.action_params(:key1, :key2)` — safe param extraction (strong params)

**Authorization:** The `condition:` proc receives the current user. If it returns false, the action returns 403 and is hidden from the UI.

**Form fields:** Actions with `form_fields:` render a form page before execution. Supported types: `:text`, `:textarea`, `:number`, `:boolean`, `:date`, `:datetime`, `:select`.

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

IronAdmin uses the standard Rails `I18n.locale`. Set it in your application controller or via a `before_action` in the IronAdmin configuration:

```ruby
IronAdmin.configure do |config|
  config.before_action do
    I18n.locale = iron_admin_current_user&.locale || :en
  end
end
```

## Custom Adapters

IronAdmin uses an adapter pattern to decouple from any specific ORM. It ships with `ActiveRecord` and `Mongoid` adapters, but you can create adapters for any data source (Sequel, HTTP APIs, DynamoDB, etc.).

See the [Building a Custom Adapter](custom-adapters.md) guide for the complete reference, including all 36 methods, duck type contracts, QueryBuilder integration, and testing patterns.

## Testing Resources

```ruby
RSpec.describe UserResource do
  it "maps to User model" do
    expect(UserResource.model).to eq(User)
  end

  it "resolves fields from schema" do
    fields = UserResource.resolved_fields
    expect(fields.map(&:name)).to include(:email, :name)
  end
end
```
