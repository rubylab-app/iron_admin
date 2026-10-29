# Fields

IronAdmin automatically infers field types from your model's schema (ActiveRecord columns or Mongoid fields).

## Automatic Inference

| DB Column Type | Field Type |
|----------------|------------|
| `string` | `:text` |
| `text` | `:textarea` |
| `integer`, `float`, `decimal` | `:number` |
| `boolean` | `:boolean` |
| `date` | `:date` |
| `datetime` | `:datetime` |
| `time` | `:time` |
| `json`, `jsonb` | `:json` |
| Enum column | `:select` (with enum values as choices) |
| `belongs_to` association | `:belongs_to` |

## Overriding Fields

```ruby
module IronAdmin
  module Resources
    class UserResource < IronAdmin::Resource
      field :status, type: :badge, colors: {
        active: :green,
        suspended: :red,
        pending: :yellow
      }
    end
  end
end
```

Overrides merge with inferred fields. You only need to specify the fields you want to change.

## Field Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | Symbol | Column name |
| `type` | Symbol | Field type |
| `visible` | Boolean/Proc | Whether the field is shown. Proc receives `(current_user)` |
| `readonly` | Boolean/Proc | Whether the field is editable. Proc receives `(current_user)` |

## Dynamic Visibility and Readonly

```ruby
module IronAdmin
  module Resources
    class SalaryResource < IronAdmin::Resource
      field :amount, visible: ->(user) { user.admin? || user.hr? }
      field :department, readonly: ->(user) { !user.admin? }
    end
  end
end
```

Visibility and readonly rules are enforced across:
- Index table columns
- Show page fields
- Form fields (readonly fields are not rendered, and values submitted for them are not assigned on create or update; the `<name>_purge` remove-file parameter of a readonly `:file` field is still honored)
- CSV/JSON exports
- Search queries

## Badge Colors

A `:badge` field shows its value as a badge. The color of a value comes from, in this order:
the field's `colors:` option, `config.badge_colors`, and else `:gray`. The classes of each color
come from the current theme's `badge_palette`, with a dot from `badge_dot_palette` (see
[Badges, alerts and chips](theming.md#badges-alerts-and-chips)). Its color names are `:green`,
`:red`, `:yellow`, `:blue`, `:indigo`, `:purple`, `:pink`, `:orange`, `:teal` and `:gray`.

### Default Badge Colors for Common Status Values

IronAdmin assigns colors to common status values without configuration
(`IronAdmin::Configuration::DEFAULT_BADGE_COLORS`):

| Status Value | Color |
|--------------|-------|
| `active`, `enabled`, `completed`, `done`, `success`, `approved`, `accepted`, `published` | Green |
| `pending` | Yellow |
| `processing`, `in_progress` | Blue |
| `failed`, `error`, `cancelled`, `canceled`, `rejected`, `declined`, `expired`, `suspended`, `blocked` | Red |
| `inactive`, `disabled`, `unpublished`, `draft`, `archived` | Gray |
| `true`, `"true"`, `"yes"` | Green |
| `false`, `"false"`, `"no"` | Red |

Example:

```ruby
module IronAdmin
  module Resources
    class OrderResource < IronAdmin::Resource
      # No colors needed - auto-detected from value
      field :status, type: :badge
    end
  end
end

# Order with status "pending" will show a yellow badge
# Order with status "completed" will show a green badge
```

Override auto-detected colors by providing explicit colors:

```ruby
field :status, type: :badge, colors: {
  pending: :orange,    # Override default yellow
  completed: :blue     # Override default green
}
```

Map more values for every badge field with `config.badge_colors` (add entries; assigning a new
Hash replaces the defaults):

```ruby
IronAdmin.configure do |config|
  config.badge_colors["on_hold"] = "orange"
end
```

To add a color, such as `field :tier, type: :badge, colors: { vip: :cyan }`, add it to the
theme's `badge_palette` and `badge_dot_palette`. Each theme has its own palettes, so a dark
theme can give the color its own classes:

```ruby
IronAdmin.configure do |config|
  config.theme do |t|
    t.badge_palette[:cyan] = "bg-cyan-50 text-cyan-700 ring-1 ring-inset ring-cyan-600/20"
    t.badge_dot_palette[:cyan] = "bg-cyan-500"
  end
end
```

An entry in `config.badge_colors` that maps a color name Symbol to classes, such as
`config.badge_colors[:cyan] = "bg-cyan-100 text-cyan-800"`, also defines a color. It wins over
the palettes, uses the same classes in every theme, and its badges have no dot.

## Name-Convention Fields

IronAdmin auto-infers certain field types based on column naming patterns:

### URL Fields

Columns matching `*_url`, `website`, or `homepage` are auto-inferred as `:url` fields.

```ruby
# Auto-inferred from column name
# website column -> :url type
# homepage_url column -> :url type

# Or set explicitly:
field :link, type: :url
```

On show and index pages, URL values are rendered as clickable links. On forms, a URL input is rendered with an `https://` placeholder.

### Email Fields

Columns matching `email` or `*_email` are auto-inferred as `:email` fields.

```ruby
# Auto-inferred from column name
# email column -> :email type
# work_email column -> :email type

# Or set explicitly:
field :contact, type: :email
```

On show and index pages, email values are rendered as clickable `mailto:` links. On forms, an email input is rendered.

## File Fields (ActiveStorage)

### Single File (`:file`)

For models using `has_one_attached`:

```ruby
class User < ApplicationRecord
  has_one_attached :avatar
end

module IronAdmin
  module Resources
    class UserResource < IronAdmin::Resource
      field :avatar, type: :file
    end
  end
end
```

On show pages, images are displayed as thumbnails and other file types as download links. Forms render a file upload input with a remove option for existing files.

### Multiple Files (`:files`)

For models using `has_many_attached`:

```ruby
class Product < ApplicationRecord
  has_many_attached :images
end

module IronAdmin
  module Resources
    class ProductResource < IronAdmin::Resource
      field :images, type: :files
    end
  end
end
```

Forms render a multi-file upload input. Show pages display all attached files with previews.

## Rich Text Field (ActionText)

For models using `has_rich_text`:

```ruby
class Article < ApplicationRecord
  has_rich_text :body
end

module IronAdmin
  module Resources
    class ArticleResource < IronAdmin::Resource
      field :body, type: :rich_text
    end
  end
end
```

On forms, a Trix WYSIWYG editor is rendered. On show pages, the rich text content is displayed with HTML formatting. On index pages and dashboard recent tables it is shown as plain text, truncated like long text fields (see [Index Text Truncation](#index-text-truncation)): no HTML from the content is rendered, and attachments appear as their caption or `[filename]`.

## Password Field

```ruby
module IronAdmin
  module Resources
    class UserResource < IronAdmin::Resource
      field :password, type: :password
    end
  end
end
```

Renders a password input with masking on forms. Leaving it blank on an edit form keeps the stored value. The value is never displayed on show or index pages, and never exported: CSV and JSON exports leave `:password` fields out, and a `:password` field listed in `export_fields` is exported as `[FILTERED]`. A `:password` field also gets no inferred index filter, is never searched (search box, `field:value` queries, global search, autocomplete), and cannot be sorted on.

## Tags Field

```ruby
module IronAdmin
  module Resources
    class ArticleResource < IronAdmin::Resource
      field :tags, type: :tags
    end
  end
end
```

On forms, renders a tag input where users can type and press Enter to add tags, and click to remove them. Tags are stored as comma-separated values. On show pages, tags are displayed as a list of badges.

## Markdown Field

```ruby
module IronAdmin
  module Resources
    class PostResource < IronAdmin::Resource
      field :body, type: :markdown
    end
  end
end
```

Renders a monospace text area on forms with a markdown placeholder. On show pages, the content is rendered as HTML with [Redcarpet](https://github.com/vmg/redcarpet) when the app bundles it (raw HTML in the markdown is filtered out), and shown as plain text otherwise. Rendered markdown and rich text use Trix's content styles (`trix-content`) for headings, lists, quotes and code when the app loads Action Text.

## Color Field

```ruby
module IronAdmin
  module Resources
    class ThemeResource < IronAdmin::Resource
      field :primary_color, type: :color
    end
  end
end
```

On show and index pages, displays a color swatch next to the hex value. On forms, renders a color picker alongside a hex text input:

- Only the text input is submitted, as `record[<field>]`. The picker has no `name`; its id is `record_<field>_picker` and its accessible label is "<Field> picker" (`iron_admin.fields.color_picker_label`).
- The `cp-color-field` Stimulus controller keeps the two in sync: picking a color fills the text input, and typing a hex color moves the picker. A blank field stays blank.
- The text input accepts `#rgb` or `#rrggbb` only (pattern `#(?:[0-9a-fA-F]{3}){1,2}`). Anything else is rejected by the browser with the hint `iron_admin.fields.color_invalid`.
- Without JavaScript, the text input still works and the picker only shows the color.

For columns that store other CSS color formats (names such as `red`, `rgb(...)`, or `#rrggbbaa`), use `type: :text` or a custom field type instead.

## Currency Field

```ruby
module IronAdmin
  module Resources
    class ProductResource < IronAdmin::Resource
      field :price, type: :currency
      # Or with a custom symbol:
      field :price, type: :currency, symbol: "EUR"
    end
  end
end
```

On show and index pages, displays the value formatted with a currency symbol prefix (defaults to `$`). On forms, renders a number input with the currency symbol.

## Boolean Field

```ruby
module IronAdmin
  module Resources
    class UserResource < IronAdmin::Resource
      field :active, type: :boolean
    end
  end
end
```

Boolean fields are auto-inferred from boolean database columns. On show and index pages, `true` values display a green check icon and `false` values display a red X icon (instead of raw `true`/`false` text). Next to the icon, visually hidden text ("Yes" or "No", from `iron_admin.fields.boolean_true` and `boolean_false`) tells screen readers the value.

## Date and DateTime Fields

```ruby
module IronAdmin
  module Resources
    class EventResource < IronAdmin::Resource
      field :start_date, type: :date
      field :starts_at, type: :datetime
    end
  end
end
```

Date and datetime fields are auto-inferred from their database column types. On show and index pages, a date uses the field's `format:` or `"%b %d, %Y"` (`Jan 15, 2026`). A datetime uses `format:` or `"%b %d, %Y at %l:%M %p"`, then squeezes the extra space (`Jan 15, 2026 at 2:05 PM`). `format:` is a strftime string. A Proc is not called: a datetime raises `NoMethodError`, and a `Date` raises `TypeError`. Other field types ignore `format:`. The import preview uses `format:` only when it is a String.

## Index Text Truncation

On index pages, `:text` and `:textarea` fields that exceed 50 characters are automatically truncated with an ellipsis. The full text is available via a tooltip on hover. `:rich_text` fields are reduced to their plain text first, then truncated the same way.

## Polymorphic Belongs To

IronAdmin auto-detects polymorphic `belongs_to` associations via `FieldInferrer`. When a model has `*_type` and `*_id` column pairs, a `:polymorphic_belongs_to` field is generated.

```ruby
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end

module IronAdmin
  module Resources
    class CommentResource < IronAdmin::Resource
      belongs_to :commentable, polymorphic: true, types: [Article, Photo, Video]
    end
  end
end
```

On forms, a type selector dropdown and an ID selector are rendered. On show and index pages, the associated record is displayed as a linked reference (e.g., "Article #42").

## Custom Field Types (FieldTypeRegistry)

You can register custom field types using the `FieldTypeRegistry` API. The form
input is a String on `config.components.fields`. IronAdmin constantizes that String
when the form renders, so a reload is picked up on the next request. See
[Field input overrides](components.md#field-input-overrides). The override wins over
`form_component` and does not change show or index pages.

Register `display` and `index_display` once. Those blocks must not call a constant
Zeitwerk can reload. The registry raises `ArgumentError`
(`Field type :star_rating is already registered`) on a second `register`.

`form_component` is the wrong place for this class. Rails 8 does not autoload
constants while initializers run, so naming `MyApp::StarRatingComponent` there
raises `NameError` (`uninitialized constant MyApp`) at boot. `form_component`
stores the class: a String has no `new`, and a class captured at boot goes stale
after a reload as soon as it calls a sibling constant.

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

The component takes `form:`, `field:` and `record:`. `StarScale` sits in the same
file. The String is constantized on each render, so the form uses the reloaded
component and that sibling.

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

Then use the type in a resource:

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

The `display` block controls show page rendering, `index_display` controls index table rendering (falls back to `display` if not provided), and `config.components.fields` controls the form input.
