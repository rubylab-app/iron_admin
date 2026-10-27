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
class UserResource < IronAdmin::Resource
  field :status, type: :badge, colors: {
    active: :green,
    suspended: :red,
    pending: :yellow
  }
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
class SalaryResource < IronAdmin::Resource
  field :amount, visible: ->(user) { user.admin? || user.hr? }
  field :department, readonly: ->(user) { !user.admin? }
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
class OrderResource < IronAdmin::Resource
  # No colors needed - auto-detected from value
  field :status, type: :badge
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

class UserResource < IronAdmin::Resource
  field :avatar, type: :file
end
```

On show pages, images are displayed as thumbnails and other file types as download links. Forms render a file upload input with a remove option for existing files.

### Multiple Files (`:files`)

For models using `has_many_attached`:

```ruby
class Product < ApplicationRecord
  has_many_attached :images
end

class ProductResource < IronAdmin::Resource
  field :images, type: :files
end
```

Forms render a multi-file upload input. Show pages display all attached files with previews.

## Rich Text Field (ActionText)

For models using `has_rich_text`:

```ruby
class Article < ApplicationRecord
  has_rich_text :body
end

class ArticleResource < IronAdmin::Resource
  field :body, type: :rich_text
end
```

On forms, a Trix WYSIWYG editor is rendered. On show pages, the rich text content is displayed with HTML formatting. On index pages and dashboard recent tables it is shown as plain text, truncated like long text fields (see [Index Text Truncation](#index-text-truncation)): no HTML from the content is rendered, and attachments appear as their caption or `[filename]`.

## Password Field

```ruby
class UserResource < IronAdmin::Resource
  field :password, type: :password
end
```

Renders a password input with masking on forms. Leaving it blank on an edit form keeps the stored value. The value is never displayed on show or index pages, and never exported: CSV and JSON exports leave `:password` fields out, and a `:password` field listed in `export_fields` is exported as `[FILTERED]`. A `:password` field also gets no inferred index filter, is never searched (search box, `field:value` queries, global search, autocomplete), and cannot be sorted on.

## Tags Field

```ruby
class ArticleResource < IronAdmin::Resource
  field :tags, type: :tags
end
```

On forms, renders a tag input where users can type and press Enter to add tags, and click to remove them. Tags are stored as comma-separated values. On show pages, tags are displayed as a list of badges.

## Markdown Field

```ruby
class PostResource < IronAdmin::Resource
  field :body, type: :markdown
end
```

Renders a monospace text area on forms with a markdown placeholder. On show pages, the raw markdown content is displayed.

## Color Field

```ruby
class ThemeResource < IronAdmin::Resource
  field :primary_color, type: :color
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
class ProductResource < IronAdmin::Resource
  field :price, type: :currency
  # Or with a custom symbol:
  field :price, type: :currency, symbol: "EUR"
end
```

On show and index pages, displays the value formatted with a currency symbol prefix (defaults to `$`). On forms, renders a number input with the currency symbol.

## Boolean Field

```ruby
class UserResource < IronAdmin::Resource
  field :active, type: :boolean
end
```

Boolean fields are auto-inferred from boolean database columns. On show and index pages, `true` values display a green check icon and `false` values display a red X icon (instead of raw `true`/`false` text). Next to the icon, visually hidden text ("Yes" or "No", from `iron_admin.fields.boolean_true` and `boolean_false`) tells screen readers the value.

## Date and DateTime Fields

```ruby
class EventResource < IronAdmin::Resource
  field :start_date, type: :date
  field :starts_at, type: :datetime
end
```

Date and datetime fields are auto-inferred from their database column types. On show and index pages, dates are displayed in human-readable format (e.g., "January 15, 2026") and datetimes include the time component.

## Index Text Truncation

On index pages, `:text` and `:textarea` fields that exceed 50 characters are automatically truncated with an ellipsis. The full text is available via a tooltip on hover. `:rich_text` fields are reduced to their plain text first, then truncated the same way.

## Polymorphic Belongs To

IronAdmin auto-detects polymorphic `belongs_to` associations via `FieldInferrer`. When a model has `*_type` and `*_id` column pairs, a `:polymorphic_belongs_to` field is generated.

```ruby
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end

class CommentResource < IronAdmin::Resource
  belongs_to :commentable, polymorphic: true, types: [Article, Photo, Video]
end
```

On forms, a type selector dropdown and an ID selector are rendered. On show and index pages, the associated record is displayed as a linked reference (e.g., "Article #42").

## Custom Field Types (FieldTypeRegistry)

You can register custom field types using the `FieldTypeRegistry` API:

```ruby
IronAdmin::FieldTypeRegistry.register(:star_rating) do
  display do |record, field|
    value = record.public_send(field.name)
    value.to_i.times.map { "&#9733;" }.join.html_safe
  end

  index_display do |record, field|
    value = record.public_send(field.name)
    "#{value}/5"
  end

  # Optional: specify a custom ViewComponent for the form
  form_component MyApp::StarRatingComponent

  # Or a partial path:
  # form_partial "shared/star_rating_input"
end
```

Then use it in a resource:

```ruby
class ReviewResource < IronAdmin::Resource
  field :rating, type: :star_rating
end
```

The `display` block controls show page rendering, `index_display` controls index table rendering (falls back to `display` if not provided), and `form_component` or `form_partial` controls the form input.
