# Theming

IronAdmin provides a granular theme system with 40+ CSS class properties. All use Tailwind CSS classes.

## Basic Configuration

```ruby
IronAdmin.configure do |config|
  config.theme do |t|
    t.btn_primary = "bg-blue-600 text-white hover:bg-blue-700"
    t.sidebar_bg = "bg-slate-900"
    t.link = "text-blue-600 hover:text-blue-800"
  end
end
```

## Full Theme Example (Rose/Slate)

```ruby
config.theme do |t|
  t.btn_primary = "bg-rose-600 text-white hover:bg-rose-700 focus:ring-2 focus:ring-rose-500/20 focus:ring-offset-1"
  t.btn_secondary = "bg-white text-slate-700 border border-slate-300 hover:bg-slate-50 hover:border-slate-400"
  t.btn_danger = "bg-red-600 text-white hover:bg-red-700"
  t.btn_ghost = "bg-slate-100 text-slate-700 hover:bg-slate-200"

  t.link = "text-rose-600 hover:text-rose-800"
  t.link_muted = "text-slate-500 hover:text-slate-700"

  t.input_border = "border-slate-300 hover:border-slate-400"
  t.input_focus = "focus:border-rose-500 focus:ring-2 focus:ring-rose-500/20"
  t.checkbox_checked = "checked:border-rose-600 checked:bg-rose-600 focus:ring-2 focus:ring-rose-500/20"

  t.scope_active = "border-rose-600 text-rose-600"
  t.scope_inactive = "border-transparent text-slate-500 hover:text-slate-700 hover:border-slate-300"

  t.badge_count = "bg-rose-600 text-white"

  t.sidebar_bg = "bg-slate-950"
  t.sidebar_title = "text-white"
  t.sidebar_link = "text-slate-400"
  t.sidebar_link_hover = "hover:bg-slate-800 hover:text-white"
  t.sidebar_link_active = "bg-slate-800 text-white"
  t.sidebar_group_label = "text-slate-500"

  t.navbar_bg = "bg-white"
  t.navbar_border = "border-slate-200"
  t.navbar_search_bg = "bg-slate-50"

  t.table_header_bg = "bg-slate-50"
  t.table_row_hover = "hover:bg-slate-50"
  t.table_border = "divide-slate-200"

  t.card_bg = "bg-white"
  t.card_border = "border-slate-200"

  t.body_text = "text-slate-900"
  t.muted_text = "text-slate-500"
  t.label_text = "text-slate-700"
end
```

## Theme Properties by Category

See [Theme Properties Reference](../reference/theme-properties.md) for the complete list with defaults.

### Categories

- **Buttons**: `btn_primary`, `btn_secondary`, `btn_danger`, `btn_ghost`
- **Links**: `link`, `link_muted`
- **Focus & Inputs**: `focus_ring`, `input_border`, `input_focus`, `checkbox_checked`
- **Scopes/Tabs**: `scope_active`, `scope_inactive`
- **Badge**: `badge_count`
- **Sidebar**: `sidebar_bg`, `sidebar_title`, `sidebar_link`, `sidebar_link_hover`, `sidebar_link_active`, `sidebar_group_label`
- **Navbar**: `navbar_bg`, `navbar_border`, `navbar_search_bg`, `navbar_search_focus_bg`
- **Table**: `table_header_bg`, `table_row_hover`, `table_border`
- **Cards**: `card_bg`, `card_border`, `card_shadow`
- **Typography**: `font_family`, `heading_weight`, `body_text`, `muted_text`, `label_text`
- **Layout**: `border_radius`

### Current page in the sidebar

The sidebar link for the current page gets `aria-current="page"` and the `sidebar_link_active`
classes **instead of** `sidebar_link` and `sidebar_link_hover`, so give it a text color as well as
a background. The default, `bg-gray-800 text-white`, matches the default hover colors.

- The **Dashboard** link is current on the dashboard only.
- A **resource** link is current on every page of that resource: index, show, new and edit
  (including the form shown again after a failed save), imports and action forms.
- A **tool** link is current on the tool's page and its action forms.
- A custom **menu item** (for example from a plugin) is current when the request path is the
  item's path. The query string, the fragment and a trailing slash are ignored. For an item
  with an absolute URL, the scheme and host must match too.

`sidebar_link_hover` must use `hover:` variants (for example `hover:bg-gray-800`). Without
them, every link looks like the current one.

## Theme Helpers in Views

Theme values are accessible via helper methods prefixed with `cp_`:

```ruby
cp_btn_primary    # => "bg-indigo-600 text-white hover:bg-indigo-700 ..."
cp_sidebar_bg     # => "bg-gray-900"
cp_card           # => "bg-white"
cp_link           # => "text-indigo-600 hover:text-indigo-900"
```

## Badge Colors

```ruby
IronAdmin.configure do |config|
  config.badge_colors[:cyan] = "bg-cyan-100 text-cyan-800"
end
```

Used with badge fields:

```ruby
field :status, type: :badge, colors: { active: :green, suspended: :red }
```
