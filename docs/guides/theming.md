# Theming

Every admin page is drawn from a **theme**, an `IronAdmin::Configuration::Theme`. Its
properties hold Tailwind CSS classes, plus a few CSS colors for charts, a font stylesheet URL
and a color scheme. IronAdmin ships one theme, **Neutral**, and uses it by default. You can:

- change the default theme's properties with `config.theme`,
- register more named themes with `config.register_theme`,
- choose which theme each request uses with `config.theme_resolver`. By default the resolver
  reads a cookie that the theme switcher in the navbar sets.

Sections:

- [Neutral, the default look](#neutral-the-default-look)
- [Customizing the default theme](#customizing-the-default-theme)
- [Theme properties](#theme-properties)
- [Registering more themes](#registering-more-themes)
- [Choosing the default theme](#choosing-the-default-theme)
- [Picking a theme per request](#picking-a-theme-per-request)
- [The theme switcher and its cookie](#the-theme-switcher-and-its-cookie)
- [Using the theme in your own components](#using-the-theme-in-your-own-components)
- [Fonts](#fonts)
- [Color scheme, dark themes and charts](#color-scheme-dark-themes-and-charts)
- [Badges, alerts and chips](#badges-alerts-and-chips)
- [Tailwind: literal classes and source scanning](#tailwind-literal-classes-and-source-scanning)
- [For contributors: the theme guards](#for-contributors-the-theme-guards)

## Neutral, the default look

Neutral is a minimal light look in the style of current developer tools:

- a `zinc-50` page and sidebar, with a white navbar and white cards, panels and tables,
- 1px `zinc-200` borders, 8px corners on cards and panels (`rounded-lg`), 6px corners on
  buttons and inputs (`rounded-md`), and almost no shadow (`shadow-xs`),
- the [Inter](https://rsms.me/inter/) typeface, loaded from Google Fonts (see [Fonts](#fonts)),
- a black primary button and an indigo accent for links, focus outlines, the current sidebar
  link and charts,
- compact tables: `px-4 py-2.5` cells, sentence-case headers, and tabular digits in number and
  currency columns,
- tinted badges with a colored dot,
- 36px buttons and inputs, and a 56px navbar whose search box takes the focus on ⌘K (Ctrl K on
  platforms other than Apple's).

Neutral's text colors meet WCAG AA contrast on the backgrounds they are drawn on.

## Customizing the default theme

`config.theme` yields the default theme. That is Neutral, unless you
[choose another default](#choosing-the-default-theme). The block can set any property, and
the properties you leave alone keep their Neutral values:

```ruby
# config/initializers/iron_admin.rb
IronAdmin.configure do |config|
  config.theme do |t|
    t.btn_primary = "bg-emerald-700 text-white hover:bg-emerald-600 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
    t.link = "text-emerald-700 hover:text-emerald-600"
    t.focus_ring = "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
    t.input_focus = "focus:border-emerald-600 focus:ring-3 focus:ring-emerald-600/15"
  end
end
```

`config.theme` also returns the theme, so `config.theme.link = "text-emerald-700"` works too.

An assignment replaces the whole value: the theme does not merge your classes with Neutral's.
When you change a property that has hover or focus states, write those classes as well.

### Change whole groups

Properties work together. If you give the sidebar a dark background, change its text colors
too, or Neutral's dark text stays on your dark background:

```ruby
config.theme do |t|
  t.sidebar_bg = "bg-zinc-900"
  t.sidebar_border = ""
  t.sidebar_title = "text-white"
  t.sidebar_link = "text-zinc-400"
  t.sidebar_link_hover = "hover:bg-zinc-800 hover:text-white"
  t.sidebar_link_active = "bg-zinc-800 text-white"
  t.sidebar_group_label = "text-zinc-400"
end
```

### The current page in the sidebar

The sidebar link for the current page gets `aria-current="page"` and the `sidebar_link_active`
classes **instead of** `sidebar_link` and `sidebar_link_hover`, so give it a text color as well
as a background. The link is `relative`, so `before:` utilities can draw a marker. Neutral
draws a white pill with a thin ring and a 2px indigo bar on its left edge.

- The **Dashboard** link is current on the dashboard only.
- A **resource** link is current on every page of that resource: index, show, new and edit
  (including the form shown again after a failed save), imports and action forms.
- A **tool** link is current on the tool's page and its action forms.
- A custom **menu item** (for example from a plugin) is current when the request path is the
  item's path. The query string, the fragment and a trailing slash are ignored. For an item
  with an absolute URL, the scheme and host must match too.

`sidebar_link_hover` must use `hover:` variants (for example `hover:bg-zinc-800`). Without
them, every link looks like the current one.

### Theme helpers in views

Templates of the engine, and views you override in `app/views/iron_admin/`, can call
`IronAdmin::ThemeHelper`. Its `t` returns the theme of the current request, and its `cp_`
helpers return ready-made class strings:

```ruby
t.link            # => "text-indigo-600 hover:text-indigo-500"
cp_btn_primary    # => "inline-flex h-9 shrink-0 items-center … bg-zinc-900 text-white hover:bg-zinc-700 …"
cp_input_class    # => "block w-full h-9 px-3 text-sm … border-zinc-200 hover:border-zinc-300 …"
cp_input_class(error: true) # input_error replaces input_border and input_focus
cp_card           # => "bg-white border border-zinc-200 rounded-lg shadow-xs"
cp_sidebar_link   # => "text-zinc-600 hover:bg-zinc-200/60 hover:text-zinc-900"
```

The button and input helpers (`cp_btn_primary`, `cp_btn_secondary`, `cp_btn_danger`,
`cp_btn_ghost`, `cp_input_class`, `cp_select_class`, `cp_textarea_class`, `cp_checkbox_class`,
`cp_radio_class`, `cp_file_input_class`) return complete controls built by
`IronAdmin::Form::ControlClasses`: buttons, inputs and selects are 36px high, checkboxes and
radio buttons 16px.

## Theme properties

A theme has 84 properties. Most hold Tailwind classes. The table lists each one with its
Neutral value and what it controls.

**What a property may hold.** A CSS property is set either by a template or by a theme
property, never both, because Tailwind v4 does not guarantee which of two conflicting utilities
wins. Templates own the layout, spacing, sizes and font sizes. Theme properties own colors,
backgrounds, border colors, border width (`border_width`), radius (`border_radius`,
`control_radius`, `checkbox_radius`), shadows, font families, text transform and letter
spacing. A few properties are complete recipes that also set a size, weight or padding:
`page_title`, `card_title`, `table_header_text`, `table_cell_padding`, `metric_label` and
`metric_value`. So:

- don't add padding, heights or font sizes to a color property such as `card_bg`. Two padding
  classes on one element have no reliable winner;
- don't use Tailwind's `dark:` variant. It follows the visitor's operating system, not the
  theme. Write a [dark theme](#registering-more-themes) with dark colors instead.

### Buttons and links

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `btn_primary` | `bg-zinc-900 text-white hover:bg-zinc-700 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500` | Primary buttons, such as form submit buttons and the filter panel's Apply: colors, hover and keyboard focus outline. Primary buttons don't get `focus_ring`, so keep `focus-visible:` classes in this value |
| `btn_secondary` | `bg-white text-zinc-900 border border-zinc-200 hover:bg-zinc-50 hover:border-zinc-300` | Secondary buttons, such as member and bulk actions and the Filters button: colors, border (width included) and hover |
| `btn_danger` | `bg-red-600 text-white hover:bg-red-700` | Destructive buttons, such as Delete |
| `btn_ghost` | `bg-transparent text-zinc-700 hover:bg-zinc-100 hover:text-zinc-900` | Ghost and icon buttons: the menu and close buttons, the theme switcher, modal close buttons. They get no `control_shadow` |
| `link` | `text-indigo-600 hover:text-indigo-500` | Links in tables and text, such as an index row's record link and "View all" |
| `link_muted` | `text-zinc-500 hover:text-zinc-900` | Secondary links, such as breadcrumbs and the filter panel's Clear link |

### Forms and controls

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `focus_ring` | `focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500` | Keyboard focus outline of every interactive element except text inputs (which use `input_focus`) and primary buttons: secondary, danger and ghost buttons, sidebar links, scope tabs, pagination, dropdown and switcher items, list rows. Use `focus-visible:` variants |
| `input_border` | `border-zinc-200 hover:border-zinc-300` | Border color, with hover, of inputs, selects, textareas, the file input and the navbar search |
| `input_focus` | `focus:border-indigo-500 focus:ring-3 focus:ring-indigo-500/15` | Focus state of those controls: border color and ring |
| `input_error` | `border-red-400 focus:border-red-500 focus:ring-3 focus:ring-red-500/20` | Used **instead of** `input_border` and `input_focus` on a control whose value failed validation, so include the focus ring |
| `placeholder_text` | `placeholder:text-zinc-500` | Placeholder color, with the `placeholder:` variant |
| `checkbox_checked` | `checked:border-indigo-600 checked:bg-indigo-600 focus:ring-3 focus:ring-indigo-500/15` | Checked checkboxes and radio buttons: border and background color (the check mark and the dot are white), and their focus ring |
| `checkbox_border` | `border-zinc-300` | Border color of unchecked checkboxes and radio buttons. They don't use `input_border`, whose hover color would cover the checked border |
| `checkbox_radius` | `rounded-sm` | Radius of checkboxes. Radio buttons are always round |
| `control_radius` | `rounded-md` | Radius of buttons, inputs, selects, dropdown and switcher items, sidebar links, pagination links, icon tiles and tooltips |
| `control_shadow` | `shadow-xs` | Shadow of inputs, selects, textareas, checkboxes, radio buttons and every button except ghost ones. Empty = none |
| `disabled_text` | `text-zinc-300` | Unavailable pagination links (Previous on the first page, Next on the last) |

### Scope tabs and counts

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `scope_active` | `border-zinc-900 text-zinc-900` | The current scope tab: underline color and text color |
| `scope_inactive` | `border-transparent text-zinc-500 hover:text-zinc-900 hover:border-zinc-300` | The other scope tabs, with their hover |
| `badge_count` | `bg-zinc-100 text-zinc-700` | Count bubbles, such as the number of active filters on the Filters button |

### Sidebar

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `sidebar_bg` | `bg-zinc-50` | Sidebar background, also as the mobile drawer |
| `sidebar_border` | `lg:border-r border-zinc-200` | The edge between the sidebar and the page: side, width and color. With `lg:`, the mobile drawer has no border |
| `sidebar_title` | `text-zinc-900` | Text color of the sidebar, which the brand (`config.title`) uses |
| `sidebar_link` | `text-zinc-600` | Text color of the sidebar links |
| `sidebar_link_hover` | `hover:bg-zinc-200/60 hover:text-zinc-900` | Hover of the sidebar links (use `hover:` variants) |
| `sidebar_link_active` | `bg-white text-zinc-900 shadow-xs ring-1 ring-zinc-200 before:absolute before:left-0 before:inset-y-2 before:w-0.5 before:rounded-full before:bg-indigo-500` | The link of the current page, **instead of** `sidebar_link` and `sidebar_link_hover` (see [above](#the-current-page-in-the-sidebar)) |
| `sidebar_group_label` | `text-zinc-500` | Color of the group labels. Their case comes from `label_transform` |

### Navbar

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `navbar_bg` | `bg-white` | Navbar background |
| `navbar_border` | `border-zinc-200` | Color of the navbar's bottom border |
| `navbar_search_bg` | `bg-zinc-50` | Background of the navbar search box |
| `navbar_search_focus_bg` | `focus:bg-white` | Its background while it has the focus |
| `navbar_text` | `text-zinc-600` | Navbar text, such as the current user's name |
| `kbd` | `border-zinc-200 bg-white text-zinc-500` | The ⌘K hint in the search box: border, background and text color |
| `skip_link` | `focus:bg-white focus:text-zinc-900 focus:ring-2 focus:ring-indigo-500` | The "Skip to content" link once it has the focus (use `focus:` variants) |

### Tables

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `table_header_bg` | `bg-zinc-50` | Background of the header row (also of the sticky actions column's header) |
| `table_header_text` | `text-xs font-medium text-zinc-500` | Header cells: size, weight and color. Their case comes from `label_transform` |
| `table_cell_padding` | `px-4 py-2.5` | Padding of header and body cells, which sets how dense tables are |
| `table_frame` | `""` | Extra classes for the panel a table scrolls in, such as a ring. Empty = none |
| `table_sticky_shadow` | `shadow-[-4px_0_6px_-4px_rgba(0,0,0,0.08)]` | Edge shadow of the sticky actions column of index tables (`config.sticky_actions_column`). Empty = none |
| `table_row_hover` | `hover:bg-zinc-50` | Row hover background |
| `table_border` | `divide-zinc-200` | Lines between table rows and between the items of divided lists (dashboard lists, key/value fields). Use `divide-*` classes |

### Cards and panels

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `card_bg` | `bg-white` | Background of cards, panels, tables, dropdowns, modals, the filter panel and inputs |
| `card_border` | `border-zinc-200` | Border color of those surfaces, and of the lines inside them (panel headers, the scope tab bar, modal sections) |
| `card_shadow` | `shadow-xs` | Shadow of cards and panels |
| `popover_shadow` | `shadow-lg` | Shadow of floating surfaces: dropdown menus, the filter panel, belongs-to autocomplete results, the theme switcher panel and modals. Empty = none |
| `card_title` | `text-sm font-semibold text-zinc-900` | Titles (h2) of cards, panels, dashboard widgets and modals: size, weight and color |

### Typography

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `font_family` | `font-[family-name:Inter,ui-sans-serif,system-ui,sans-serif]` | Font family of every page (on `<body>`). Empty = the browser's default |
| `font_stylesheet_url` | `https://fonts.googleapis.com/css2?family=Inter:wght@400..700&display=swap` | Stylesheet that the layout links for the theme's fonts. `nil` = none (see [Fonts](#fonts)) |
| `heading_font` | `""` | Extra font family classes for page titles, card titles and the sidebar brand. Empty = `font_family` |
| `heading_weight` | `font-semibold` | Weight of the sidebar brand and of the `cp_heading` helper |
| `page_title` | `text-xl font-semibold tracking-tight text-zinc-900` | Page titles (h1): size, weight, tracking and color |
| `label_transform` | `""` | Case and letter spacing of small labels: sidebar group labels, table headers, metric labels and filter labels. Empty = as written. `uppercase tracking-wider` gives the 0.7 look |
| `body_text` | `text-zinc-900` | Main text color: the page, table cells, inputs, dropdown items |
| `muted_text` | `text-zinc-500` | Secondary text: hints, timestamps, record ids, empty states, pagination summaries |
| `label_text` | `text-zinc-700` | Form and filter labels |
| `error_text` | `text-red-600` | Validation messages, required marks, negative deltas, import rows with errors, and old values in the audit log |
| `success_text` | `text-emerald-700` | Positive deltas, the icon of a true boolean, and new values in the audit log |

### Layout and surfaces

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `main_bg` | `bg-zinc-50` | Page background (`<body>` and the main area) |
| `border_radius` | `rounded-lg` | Radius of cards, panels, alerts, dropdowns and modals. Buttons and inputs use `control_radius` |
| `border_width` | `border` | Width of every themed border: cards, panels, inputs, alerts, pagination, dropdowns |
| `color_scheme` | `"light"` | `"light"` or `"dark"`: the CSS color scheme of the page (see [Color scheme](#color-scheme-dark-themes-and-charts)). Not a Tailwind class |
| `swatch` | `bg-white ring-1 ring-inset ring-zinc-300` | This theme's dot in the theme switcher |
| `surface_muted` | `bg-zinc-50` | Secondary backgrounds: readonly and disabled inputs, nested form rows, file previews, the empty state icon, audit change details |
| `item_hover` | `hover:bg-zinc-100` | Hover of dropdown and switcher items, list rows, quick links and pagination links |
| `item_active` | `bg-zinc-100` | The belongs-to autocomplete option that the arrow keys highlight |
| `icon_muted` | `text-zinc-400` | Decorative icons, such as the search icon, breadcrumb separators and the empty state icon |
| `overlay_bg` | `bg-zinc-900/40` | Backdrop behind modals and the mobile sidebar drawer |

### Feedback: alerts, badges and other elements

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `alert_palette` | Hash, see [below](#badges-alerts-and-chips) | Classes (background, border color, text color) of alerts by type: `:success`, `:error`, `:warning`, `:info`. Flash messages, form errors and the audit log's warning use it |
| `badge_palette` | Hash, see [below](#badges-alerts-and-chips) | Badge classes by color name: status badges, `:badge` fields, audit actions and activity feed icons |
| `badge_dot_palette` | Hash, see [below](#badges-alerts-and-chips) | Classes of the dot inside each badge, by color name. An empty Hash (`{}`) draws no dots |
| `badge_shape` | `rounded-md font-medium` | Radius and weight of badges, chips and count bubbles |
| `chip` | `bg-zinc-100 text-zinc-700 ring-1 ring-inset ring-zinc-200` | Chips: tags, has-and-belongs-to-many records on show pages, file names, boolean group values and the column names on import pages |
| `danger_item` | `text-red-600 hover:bg-red-50 hover:text-red-700` | Destructive dropdown items, with their hover |
| `tooltip` | `bg-zinc-900 text-white` | Tooltip background and text color |
| `code_block` | `bg-zinc-950 text-zinc-100` | Background and text color of `:code` and `:json` values |
| `progress_track` | `bg-zinc-200` | Track of progress bars (`:progress` fields and dashboard progress widgets) |
| `pagination_active` | `bg-zinc-900 text-white border-zinc-900` | The current page in the pagination |

### Dashboard

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `metric_label` | `text-xs font-medium text-zinc-500` | Label of metric, stat and progress cards: size, weight and color. Its case comes from `label_transform` |
| `metric_value` | `text-2xl font-semibold tracking-tight tabular-nums text-zinc-900` | The figure of those cards: size, weight, tracking and color |
| `metric_icon` | `bg-zinc-100 text-zinc-500` | The tile behind a card's icon: background and icon color |

### Charts

These hold CSS colors, not Tailwind classes, because Chart.js draws on a canvas.

| Property | Neutral value | Controls |
|----------|---------------|----------|
| `chart_colors` | `rgba(99,102,241,0.85)`, `rgba(14,165,233,0.85)`, `rgba(16,185,129,0.85)`, `rgba(245,158,11,0.85)`, `rgba(244,63,94,0.85)`, `rgba(139,92,246,0.85)` (indigo, sky, emerald, amber, rose and violet) | Slice and bar colors of the dashboard charts (an Array) |
| `chart_border_color` | `rgb(99, 102, 241)` | Line color of line, area and radar charts, and the fill of progress bars without a color of their own |
| `chart_grid_color` | `rgba(228, 228, 231, 1)` | Grid lines and axis lines |
| `chart_text_color` | `rgb(113, 113, 122)` | Tick labels, radar point labels and the legend |

A theme also has a `name` (a Symbol, the value its cookie stores) and a `label` (the text in
the switcher), set when the theme is registered. `dark?` and `scheme_class` read `color_scheme`.

## Registering more themes

`config.register_theme(name, label: name.to_s.titleize)` builds a new theme with the Neutral
values, yields it, and stores it under `name`:

- every theme starts from the **pristine** Neutral values. It doesn't matter whether you call
  `register_theme` before or after `config.theme`; the changes `config.theme` makes to the
  default theme never carry over;
- the label defaults to the titleized name (`:high_contrast` is "High Contrast");
- registering a name again replaces that theme, and registering `:neutral` replaces the
  built-in theme;
- a blank name raises `ArgumentError`;
- the method returns the theme.

Once two or more themes are registered, the navbar shows the
[theme switcher](#the-theme-switcher-and-its-cookie).

### A complete dark theme

This theme sets every property that holds a color. The ones it leaves alone (fonts, radii,
`border_width`, `table_cell_padding`, `label_transform`, `badge_shape` and so on) keep their
Neutral values.

```ruby
# config/initializers/iron_admin.rb
IronAdmin.configure do |config|
  config.register_theme(:midnight, label: "Midnight") do |t|
    t.color_scheme = "dark"
    t.swatch = "bg-zinc-900 ring-1 ring-inset ring-zinc-600"

    # Page, sidebar and navbar
    t.main_bg = "bg-zinc-950"
    t.body_text = "text-zinc-100"
    t.muted_text = "text-zinc-400"
    t.label_text = "text-zinc-300"
    t.page_title = "text-xl font-semibold tracking-tight text-zinc-50"
    t.sidebar_bg = "bg-zinc-950"
    t.sidebar_border = "lg:border-r border-zinc-800"
    t.sidebar_title = "text-zinc-50"
    t.sidebar_link = "text-zinc-400"
    t.sidebar_link_hover = "hover:bg-zinc-800/60 hover:text-zinc-50"
    t.sidebar_link_active = "bg-zinc-800 text-zinc-50 before:absolute before:left-0 before:inset-y-2 before:w-0.5 before:rounded-full before:bg-indigo-400"
    t.sidebar_group_label = "text-zinc-400"
    t.navbar_bg = "bg-zinc-950"
    t.navbar_border = "border-zinc-800"
    t.navbar_search_bg = "bg-zinc-900"
    t.navbar_search_focus_bg = "focus:bg-zinc-900"
    t.navbar_text = "text-zinc-400"
    t.kbd = "border-zinc-700 bg-zinc-800 text-zinc-400"
    t.skip_link = "focus:bg-zinc-900 focus:text-zinc-50 focus:ring-2 focus:ring-indigo-400"
    t.overlay_bg = "bg-black/60"

    # Buttons, links and focus
    t.btn_primary = "bg-zinc-50 text-zinc-900 hover:bg-zinc-200 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-400"
    t.btn_secondary = "bg-zinc-900 text-zinc-100 border border-zinc-700 hover:bg-zinc-800 hover:border-zinc-600"
    t.btn_danger = "bg-red-600 text-white hover:bg-red-700"
    t.btn_ghost = "bg-transparent text-zinc-300 hover:bg-zinc-800 hover:text-zinc-50"
    t.link = "text-indigo-400 hover:text-indigo-300"
    t.link_muted = "text-zinc-400 hover:text-zinc-50"
    t.focus_ring = "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-400"

    # Inputs
    t.input_border = "border-zinc-700 hover:border-zinc-600"
    t.input_focus = "focus:border-indigo-400 focus:ring-3 focus:ring-indigo-400/25"
    t.input_error = "border-red-500 focus:border-red-400 focus:ring-3 focus:ring-red-400/25"
    t.placeholder_text = "placeholder:text-zinc-400"
    t.checkbox_checked = "checked:border-indigo-500 checked:bg-indigo-500 focus:ring-3 focus:ring-indigo-400/25"
    t.checkbox_border = "border-zinc-600"
    t.control_shadow = ""
    t.disabled_text = "text-zinc-600"

    # Scope tabs and counts
    t.scope_active = "border-zinc-50 text-zinc-50"
    t.scope_inactive = "border-transparent text-zinc-400 hover:text-zinc-50 hover:border-zinc-600"
    t.badge_count = "bg-zinc-800 text-zinc-300"

    # Cards, tables and surfaces
    t.card_bg = "bg-zinc-900"
    t.card_border = "border-zinc-800"
    t.card_shadow = ""
    t.popover_shadow = "shadow-xl shadow-black/40"
    t.card_title = "text-sm font-semibold text-zinc-50"
    t.table_header_bg = "bg-zinc-950"
    t.table_header_text = "text-xs font-medium text-zinc-400"
    t.table_row_hover = "hover:bg-zinc-800/50"
    t.table_border = "divide-zinc-800"
    t.table_sticky_shadow = "shadow-[-4px_0_6px_-4px_rgba(0,0,0,0.6)]"
    t.surface_muted = "bg-zinc-950"
    t.item_hover = "hover:bg-zinc-800"
    t.item_active = "bg-zinc-800"
    t.icon_muted = "text-zinc-500"

    # Text in states
    t.error_text = "text-red-400"
    t.success_text = "text-emerald-400"

    # Alerts, badges, chips and other elements
    t.alert_palette = {
      success: "bg-emerald-950/60 border-emerald-900 text-emerald-200",
      error: "bg-red-950/60 border-red-900 text-red-200",
      warning: "bg-amber-950/60 border-amber-900 text-amber-200",
      info: "bg-blue-950/60 border-blue-900 text-blue-200",
    }
    t.badge_palette = {
      green: "bg-emerald-400/10 text-emerald-300 ring-1 ring-inset ring-emerald-400/20",
      red: "bg-red-400/10 text-red-300 ring-1 ring-inset ring-red-400/20",
      yellow: "bg-amber-400/10 text-amber-300 ring-1 ring-inset ring-amber-400/20",
      blue: "bg-blue-400/10 text-blue-300 ring-1 ring-inset ring-blue-400/30",
      indigo: "bg-indigo-400/10 text-indigo-300 ring-1 ring-inset ring-indigo-400/30",
      purple: "bg-purple-400/10 text-purple-300 ring-1 ring-inset ring-purple-400/30",
      pink: "bg-pink-400/10 text-pink-300 ring-1 ring-inset ring-pink-400/20",
      orange: "bg-orange-400/10 text-orange-300 ring-1 ring-inset ring-orange-400/20",
      teal: "bg-teal-400/10 text-teal-300 ring-1 ring-inset ring-teal-400/20",
      gray: "bg-zinc-400/10 text-zinc-300 ring-1 ring-inset ring-zinc-400/20",
    }
    t.badge_dot_palette = {
      green: "bg-emerald-400", red: "bg-red-400", yellow: "bg-amber-400", blue: "bg-blue-400",
      indigo: "bg-indigo-400", purple: "bg-purple-400", pink: "bg-pink-400", orange: "bg-orange-400",
      teal: "bg-teal-400", gray: "bg-zinc-500",
    }
    t.chip = "bg-zinc-800 text-zinc-300 ring-1 ring-inset ring-zinc-700"
    t.danger_item = "text-red-400 hover:bg-red-500/10 hover:text-red-300"
    t.tooltip = "bg-zinc-100 text-zinc-900"
    t.code_block = "bg-black text-zinc-100"
    t.progress_track = "bg-zinc-800"
    t.pagination_active = "bg-zinc-50 text-zinc-900 border-zinc-50"

    # Dashboard and charts
    t.metric_label = "text-xs font-medium text-zinc-400"
    t.metric_value = "text-2xl font-semibold tracking-tight tabular-nums text-zinc-50"
    t.metric_icon = "bg-zinc-800 text-zinc-400"
    t.chart_colors = %w[
      rgba(129,140,248,0.85) rgba(56,189,248,0.85) rgba(52,211,153,0.85)
      rgba(251,191,36,0.85) rgba(251,113,133,0.85) rgba(167,139,250,0.85)
    ]
    t.chart_border_color = "rgb(129, 140, 248)"
    t.chart_grid_color = "rgba(63, 63, 70, 1)"
    t.chart_text_color = "rgb(161, 161, 170)"
  end
end
```

`color_scheme = "dark"` makes the browser draw scrollbars, date pickers and other native
controls in dark colors; see [Color scheme](#color-scheme-dark-themes-and-charts).

## Choosing the default theme

`config.default_theme` names the theme a request gets when the resolver names no registered
theme. It is `:neutral` unless you change it:

```ruby
IronAdmin.configure do |config|
  config.register_theme(:midnight, label: "Midnight") { |t| ... }
  config.default_theme = :midnight
end
```

- `config.theme` yields and returns the theme that `default_theme` names **at the moment you
  call it**. Set `default_theme` after registering that theme. Before the theme exists,
  `config.theme` still configures Neutral.
- If `default_theme` names a theme that is not registered, Neutral is used.
- `config.themes` returns the registered themes as an ordered Hash (`{ name => theme }`),
  the default theme first. The switcher lists them in that order.
- A blank name raises `ArgumentError`.

To change the look without offering a choice, customize the default theme with `config.theme`
and register nothing: with one theme, the navbar shows no switcher.

## Picking a theme per request

Before every admin request, and before authentication (so error pages and login redirects
already use it), `IronAdmin::ApplicationController` calls the resolver and stores the theme it
names for the request. By default the resolver reads the `iron_admin_theme` cookie that the
switcher sets.

`config.theme_resolver` takes a block that receives the request (an
`ActionDispatch::Request`) and returns a theme name (a String, a Symbol or `nil`):

- a name that is not registered, a blank name and `nil` give the default theme;
- if the block raises, IronAdmin logs a warning (`[IronAdmin] theme_resolver raised …`) and
  uses the default theme, so a failing resolver never breaks a page;
- the block runs on every admin request, so keep it cheap;
- the block gets no controller and no current user, because it runs before authentication.
  Read what you need from the request: `request.cookies`, `request.cookie_jar`,
  `request.session`, `request.env["warden"]`, `request.host`, `request.query_parameters`.

`config.theme_resolver` without a block returns the current resolver. The default one is
`IronAdmin::Configuration::DEFAULT_THEME_RESOLVER`.

### A theme saved per user

Say your users have an `admin_theme` string column. With Devise (Warden), the resolver can
read the signed-in user:

```ruby
config.theme_resolver do |request|
  # The switcher's cookie wins, so switching keeps working; the user's saved theme
  # applies in a browser that has no cookie yet.
  request.cookies[IronAdmin::Configuration::THEME_COOKIE].presence ||
    request.env["warden"]&.user&.admin_theme
end
```

With a Devise scope other than the default one, pass it: `request.env["warden"]&.user(:admin)`.
Without Devise, look the user up from the session, for example
`User.find_by(id: request.session[:user_id])&.admin_theme`.

The switcher only sets the cookie; it doesn't save anything to your users. If the resolver
ignores the cookie, the switcher seems to do nothing. To save the choice to the user, render
your own switcher (see [below](#replacing-or-hiding-the-switcher)) that posts to your own
controller.

### A theme from a query parameter

This resolver lets a link such as `/admin/users?theme=midnight` pick the theme, and saves it
in the cookie through `request.cookie_jar`, as the switcher does, so the next pages keep it:

```ruby
config.theme_resolver do |request|
  picked = IronAdmin.configuration.find_theme(request.query_parameters["theme"])
  if picked
    request.cookie_jar[IronAdmin::Configuration::THEME_COOKIE] = {
      value: picked.name.to_s, expires: 1.year, httponly: true, same_site: :lax, secure: request.ssl?,
    }
    picked.name
  else
    request.cookies[IronAdmin::Configuration::THEME_COOKIE]
  end
end
```

`find_theme` returns `nil` for anything that is not a registered name, so only real theme
names reach the cookie. Rails writes the cookies set on `request.cookie_jar` to the response.
Because a GET request now changes the cookie, any link, including one on another site, can
switch a visitor's theme. That's harmless for a look, but don't decide anything sensitive this
way.

## The theme switcher and its cookie

When two or more themes are registered, the navbar shows a swatch button (its accessible name
is "Theme: <label>"). It opens a menu with one button per theme: the theme's swatch and label,
a check mark and `aria-pressed="true"` on the current one.

- **Keyboard:** Tab reaches the button, Enter or Space opens it, Tab moves through the themes,
  and Escape closes the menu and returns the focus to the button. A click outside closes it
  too. The `cp-disclosure` Stimulus controller handles Escape and outside clicks.
- **Request:** each theme button submits a form, `POST /admin/theme` (`iron_admin.theme_path`)
  with `theme` (the name) and `return_to` (the current path). The form has the CSRF token, and
  the endpoint is protected against forgery and authenticated like every admin page. It has
  `data-turbo="false"`: the browser loads the next page in full, so the `<html>` class, the
  fonts and the color scheme change with it.
- **Response:** for a registered name, the endpoint stores it in the cookie. Any other value
  leaves the cookie as it is and sets the flash alert `iron_admin.theme_switcher.unknown`
  ("That theme is not available."). It then redirects with `303 See Other` to `return_to` when
  that is a path on this site (it starts with a single `/`, has no backslash, space or control
  character, and has no scheme or host), and to the admin root otherwise.
- **Cookie:** `iron_admin_theme` (`IronAdmin::Configuration::THEME_COOKIE`). It holds the
  theme's name in plain text and lasts one year, with `HttpOnly`, `SameSite=Lax`, and `Secure`
  on HTTPS requests. Editing it can only pick another registered theme, because the resolver
  ignores names that are not registered.
- **Translations:** `iron_admin.theme_switcher.button_label` ("Theme: %{theme}"),
  `iron_admin.theme_switcher.menu_label` ("Themes") and `iron_admin.theme_switcher.unknown`.

The endpoint stores only the themes registered in configuration. A custom resolver can accept
other inputs, but the endpoint never does.

### Replacing or hiding the switcher

The switcher fills the `theme_switcher` component slot (see
[Components](components.md#overriding-components)). The built-in navbar renders it only when
two or more themes are registered, with `themes:` (an Array of themes, default first),
`current_theme:` and `current_user:`.

To keep several themes but hide the switcher, for example when the resolver picks the theme
per tenant, use a component that renders nothing:

```ruby
# app/components/no_theme_switcher_component.rb
class NoThemeSwitcherComponent < ViewComponent::Base
  def render?
    false
  end

  # ViewComponent needs a template or a call method, even for a component that never renders.
  def call; end
end

# config/initializers/iron_admin.rb
config.components.theme_switcher = "NoThemeSwitcherComponent"
```

A switcher of your own can post to `helpers.iron_admin.theme_path` with `theme` and
`return_to`, as the built-in one does, or to a controller of yours that also saves the choice.
A custom navbar (`config.components.navbar`) can render the slot with
`helpers.iron_admin_component(:theme_switcher, themes: IronAdmin.configuration.themes.values,
current_theme: IronAdmin.current_theme, current_user: @current_user)`.

## Using the theme in your own components

`IronAdmin.current_theme` returns the theme of the current request. Outside a request, for
example in a component spec, a mailer or a background job, it returns the default theme. Read
it in every component, view or helper you add to the admin panel:

```ruby
# app/components/admin_notice_component.rb
class AdminNoticeComponent < ViewComponent::Base
  def initialize(message:)
    @message = message
  end

  def call
    tag.div(@message, class: "p-4 text-sm #{theme.card_bg} #{theme.border_width} #{theme.card_border} " \
                             "#{theme.border_radius} #{theme.card_shadow} #{theme.body_text}")
  end

  private

  def theme
    IronAdmin.current_theme
  end
end
```

Don't read `IronAdmin.configuration.theme` in components. It always returns the default
theme, so a component that uses it keeps the default look while the rest of the page shows
another theme.

The engine's own recipes are available too, so your controls can match the built-in ones:
`IronAdmin::Form::ControlClasses.button(theme, :secondary)` (`:primary`, `:secondary`,
`:danger` or `:ghost`), `.input(theme)`, `.select(theme)`, `.textarea(theme)` and
`.checkbox(theme)`. Each returns the classes of a complete control: 36px high, or 16px for a
checkbox.

## Fonts

Three properties set the type:

- `font_family`: the font family class of every page, on `<body>`;
- `heading_font`: extra font family classes for page titles, card titles and the sidebar
  brand. Leave it empty to use `font_family`;
- `font_stylesheet_url`: a stylesheet the layout links in `<head>` to load the fonts.

When `font_stylesheet_url` is present, the layout links it with `<link rel="stylesheet">`. When
it is on `fonts.googleapis.com`, the layout first adds `<link rel="preconnect">` tags for
`fonts.googleapis.com` and `fonts.gstatic.com`, so the browser opens those connections early.
Charts draw their text in the font of the card around them, and redraw once a web font has
loaded.

Neutral loads Inter from Google Fonts with `display=swap`. The browser shows text in a fallback
font right away and swaps in Inter once it arrives, so text is never invisible while the font
loads.

**Privacy.** With a Google Fonts URL, every page view makes the visitor's browser request
`fonts.googleapis.com` and `fonts.gstatic.com`, which sends Google the visitor's IP address and
user agent. In the EU, some courts and data protection authorities treat this as a transfer of
personal data that needs consent. If that applies to you, turn the request off or host the
font yourself.

**Content Security Policy.** If your app sends a CSP header, allow both hosts, or the browser
blocks the font and Inter never loads:

```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.style_src :self, "https://fonts.googleapis.com"
    policy.font_src :self, "https://fonts.gstatic.com"
    # ... the rest of your policy
  end
end
```

**Turning the Google Fonts request off.** Set `font_stylesheet_url` to `nil`. Every
registered theme starts from Neutral and links Inter too, so do it for each theme. After the
last `register_theme`, one loop covers them all:

```ruby
IronAdmin.configure do |config|
  config.register_theme(:midnight) { |t| ... }

  config.themes.each_value { |theme| theme.font_stylesheet_url = nil }
end
```

Without the stylesheet, pages use Inter where it is installed on the visitor's computer, and
`ui-sans-serif` / `system-ui` (the operating system's font) elsewhere. For the system font
everywhere, also set `t.font_family = "font-sans"`, Tailwind's system stack.

**Hosting Inter yourself.** Put the font files and a stylesheet with their `@font-face` rules
in your app (for example `public/fonts/inter.css`), then point the theme at it:
`t.font_stylesheet_url = "/fonts/inter.css"`. The layout adds no preconnect tags for a URL
that is not on Google Fonts.

**Another font.** Use Tailwind's `font-[family-name:…]` arbitrary value and the font's
stylesheet:

```ruby
config.theme do |t|
  t.font_family = "font-[family-name:Geist,ui-sans-serif,system-ui,sans-serif]"
  t.font_stylesheet_url = "https://fonts.googleapis.com/css2?family=Geist:wght@400..700&display=swap"
  t.heading_font = "font-serif" # titles in the system serif
end
```

## Color scheme, dark themes and charts

`color_scheme` is `"light"` or `"dark"`. It is not a Tailwind class. The layout turns it into:

- a `scheme-light` or `scheme-dark` class on `<html>`, which sets the CSS `color-scheme`, so
  the browser draws scrollbars, date and time pickers, select menus and autofill in light or
  dark colors;
- a `<meta name="color-scheme" content="light">` (or `"dark"`) tag;
- a lighter chevron in selects under `scheme-dark` (drawn by the engine's stylesheet).

`color_scheme` doesn't recolor anything else: a dark theme sets dark classes in its properties,
as the [Midnight example](#a-complete-dark-theme) does. Charts don't read `color_scheme`
either. Chart.js draws on a canvas, so the chart properties hold CSS colors (hex, `rgb()` or
`rgba()`) and a dark theme sets all four:

- `chart_colors`: the slices of pie, doughnut and polar area charts, and the bars of bar
  charts;
- `chart_border_color`: the line of line, area and radar charts, whose fill is the same color
  at 10% opacity. It also fills progress bars that have no color of their own;
- `chart_grid_color`: grid and axis lines;
- `chart_text_color`: tick labels, radar point labels and the legend.

A chart's own colors win over the theme: `chart :revenue, type: :bar, colors: ["#0ea5e9"]` in
a dashboard (or `colors:` on `ChartComponent`) replaces `chart_colors`, and its first color
replaces `chart_border_color`. A dashboard `progress` widget's `color:` is a CSS color, and a
`:progress` field's `color:` option is a Tailwind class such as `bg-emerald-600`. Both replace
`chart_border_color` for that bar.

## Badges, alerts and chips

Badges take their classes from three properties:

- `badge_palette`: a Hash from color name to classes. Neutral has `:green`, `:red`, `:yellow`,
  `:blue`, `:indigo`, `:purple`, `:pink`, `:orange`, `:teal` and `:gray`; an unknown color
  uses `:gray`;
- `badge_dot_palette`: a Hash from the same names to the classes of a 6px dot before the text.
  An empty Hash (`{}`) draws badges without dots;
- `badge_shape`: the radius and weight of every badge.

| Color | Neutral `badge_palette` | Neutral `badge_dot_palette` |
|-------|-------------------------|-----------------------------|
| `:green` | `bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-600/20` | `bg-emerald-500` |
| `:red` | `bg-red-50 text-red-700 ring-1 ring-inset ring-red-600/10` | `bg-red-500` |
| `:yellow` | `bg-amber-50 text-amber-800 ring-1 ring-inset ring-amber-600/20` | `bg-amber-500` |
| `:blue` | `bg-blue-50 text-blue-700 ring-1 ring-inset ring-blue-700/10` | `bg-blue-500` |
| `:indigo` | `bg-indigo-50 text-indigo-700 ring-1 ring-inset ring-indigo-700/10` | `bg-indigo-500` |
| `:purple` | `bg-purple-50 text-purple-700 ring-1 ring-inset ring-purple-700/10` | `bg-purple-500` |
| `:pink` | `bg-pink-50 text-pink-700 ring-1 ring-inset ring-pink-700/10` | `bg-pink-500` |
| `:orange` | `bg-orange-50 text-orange-800 ring-1 ring-inset ring-orange-600/20` | `bg-orange-500` |
| `:teal` | `bg-teal-50 text-teal-700 ring-1 ring-inset ring-teal-600/20` | `bg-teal-500` |
| `:gray` | `bg-zinc-50 text-zinc-600 ring-1 ring-inset ring-zinc-500/10` | `bg-zinc-400` |

The palettes are plain Hashes, and each theme has its own copy, so you can add a color to one
theme:

```ruby
config.theme do |t|
  t.badge_palette[:cyan] = "bg-cyan-50 text-cyan-700 ring-1 ring-inset ring-cyan-600/20"
  t.badge_dot_palette[:cyan] = "bg-cyan-500"
end
```

**`config.badge_colors`.** This Hash decides which color a value gets: it maps status values
such as `"active"` to color names such as `"green"` (see
[Badge Colors](fields.md#badge-colors) for the defaults). A field's own `colors:` option wins
over it. An entry keyed by a color name Symbol with classes as its value
(`config.badge_colors[:cyan] = "bg-cyan-100 text-cyan-800"`) sets the classes of that color in
**every** theme, and those badges have no dot. That keeps the look of apps that set such
classes before 0.8. For a color that changes with the theme, set the theme's `badge_palette`
instead. Add entries with `[]=` or `merge!`: assigning a new Hash to `config.badge_colors`
replaces the default status mapping.

**Alerts.** `alert_palette` holds the background, border color and text color of each alert
type. Flash messages, the form's base errors and the audit log's warning use it. An unknown
type uses the `:info` entry:

| Type | Neutral `alert_palette` |
|------|-------------------------|
| `:success` | `bg-emerald-50 border-emerald-200 text-emerald-800` |
| `:error` | `bg-red-50 border-red-200 text-red-800` |
| `:warning` | `bg-amber-50 border-amber-200 text-amber-800` |
| `:info` | `bg-blue-50 border-blue-200 text-blue-800` |

**Chips.** Tags, has-and-belongs-to-many records on show pages, file names, boolean group
values and the column names on import pages use `chip` with `badge_shape`. The activity feed tints its icons from `badge_palette`
(an item's `icon_color` is one of its color names).

## Tailwind: literal classes and source scanning

IronAdmin ships no compiled CSS. Your app's Tailwind v4 build (tailwindcss-rails) generates
every class it finds in the files it scans. The engine's own templates and the Neutral values in
`lib/` are scanned through the `iron_admin` bridge file (see
[Installation](../getting-started/installation.md)). **The classes in your themes live in your
app, so your build must scan the file that defines them.**

Tailwind detects sources automatically from the directory the build runs in, and skips files
that `.gitignore` lists. `bin/rails tailwindcss:build` and `bin/dev` run from the app's root, so
a theme in `config/initializers/iron_admin.rb` is usually found without any setup. Name the file
explicitly when your CSS turns automatic detection off (`@import "tailwindcss" source(none);`),
when the file is ignored by Git, or just to be safe:

```css
/* app/assets/tailwind/application.css */
@import "tailwindcss";
@import "../builds/tailwind/iron_admin";
@source "../../../config/initializers/iron_admin.rb";
```

Paths in `@source` are relative to the CSS file. After you change a theme, rebuild the CSS
(`bin/rails tailwindcss:build`), or keep `bin/rails tailwindcss:watch` running. If you commit
`app/assets/builds/tailwind.css`, commit the rebuilt file too.

**Write every class as a complete literal.** Tailwind reads your source files as text: it never
runs Ruby. A class built by interpolation, such as `"bg-#{color}-600"`, never appears in the
text, so Tailwind generates no CSS for it and the element is unstyled. Write each class in full.
A Hash from names to full class strings is fine, and so is a long value split into several
string literals at a space between classes. Don't split one class, and in particular an
arbitrary value such as `shadow-[0_1px_2px_rgba(0,0,0,0.05)]`, across two string literals or
lines.

**Use Tailwind v4 utilities.** Utilities that v4 removed, such as `bg-opacity-50` (use
`bg-black/50`) and `flex-grow` (use `grow`), generate nothing, and some names changed size:
v4's `shadow-xs` is v3's `shadow-sm`, and v4's `shadow-sm` is v3's `shadow`. Variants such as `hover:`, `focus:`, `focus-visible:`, `before:`, `lg:` and
`placeholder:` work in every property.

## For contributors: the theme guards

Every color the panel draws belongs to the theme, so a registered theme can restyle all of it.
Several specs keep it that way:

- `spec/iron_admin/theme_hardcoded_colors_spec.rb` scans every `app/**/*.{haml,erb,rb,js}` file.
  It fails on any Tailwind color utility (`bg`, `text`, `border`, `divide`, `ring`, `outline`,
  `placeholder`, `fill`, `stroke`, `from`, `via`, `to`, `shadow`, `decoration`, `accent`,
  `caret`, with any variants) that uses a palette color, `white` or `black`, or an arbitrary
  color value such as `bg-[#fafafa]`. It also fails on inline `style` declarations, SVG
  attributes and JavaScript style assignments that hard-code a color. `text-current`,
  `bg-transparent`, `border-transparent`, `fill-current`, `stroke-current` and `inherit` are
  allowed, and so are styles built from theme values or record data. Each failure names the
  file, the line and the class. Take the color from a theme property instead. Colors belong in
  `lib/iron_admin/configuration/theme.rb`, which the guard doesn't scan.
- `spec/iron_admin/engine_theme_reads_spec.rb` fails when `app/` or `lib/` reads
  `IronAdmin.configuration.theme`. Read `IronAdmin.current_theme` (or `t` in views).
- `spec/iron_admin/engine_tailwind_classes_spec.rb` fails on utilities Tailwind v4 removed, on
  an important modifier placed before the variants, on fractional values in the HAML class
  shorthand (`.gap-1.5` renders the classes `gap-1` and `5`; write
  `class: "gap-1.5"`), and on arbitrary values split across string literals.
- `spec/lib/iron_admin/configuration/theme_spec.rb` checks every Neutral value and fails when a
  property is not set in `Theme#initialize`, so copies and registered themes always carry it.

To add a property: add an `attr_accessor` with YARD to its group in `theme.rb`, set its Neutral
value in the matching `init_*_defaults` method, add it to the Neutral catalog in `theme_spec.rb`,
add a row to the tables in this guide, and add a CHANGELOG entry.
