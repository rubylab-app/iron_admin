# Theme Reference

The methods, constants and helpers of the theme system. The [Theming guide](../guides/theming.md)
explains how to use them, and its [Theme properties](../guides/theming.md#theme-properties)
tables list every property with its Neutral value and what it controls.

## Properties

A theme has 94 properties, each with a reader and a writer (`theme.card_bg`,
`theme.card_bg = "bg-white"`). They hold Tailwind classes, except `font_stylesheet_url` (a URL
or `nil`), `color_scheme` (`"light"` or `"dark"`), the chart properties (CSS colors, a Chart.js point
style and a width in pixels) and the palettes (Hashes).

| Group | Properties |
|-------|------------|
| Buttons and links | `btn_primary`, `btn_secondary`, `btn_danger`, `btn_ghost`, `link`, `link_muted` |
| Forms and controls | `focus_ring`, `input_border`, `input_focus`, `input_error`, `placeholder_text`, `checkbox_checked`, `checkbox_border`, `checkbox_radius`, `control_radius`, `control_shadow`, `disabled_text` |
| Scope tabs and counts | `scope_active`, `scope_inactive`, `badge_count` |
| Sidebar | `sidebar_bg`, `sidebar_border`, `sidebar_title`, `sidebar_link`, `sidebar_link_hover`, `sidebar_link_active`, `sidebar_group_label` |
| Navbar | `navbar_bg`, `navbar_border`, `navbar_border_width`, `navbar_search_bg`, `navbar_search_focus_bg`, `navbar_text`, `kbd`, `skip_link` |
| Tables | `table_header_bg`, `table_header_text`, `table_cell_padding`, `table_frame`, `table_sticky_shadow`, `table_row_hover`, `table_sticky_row_hover`, `table_border`, `table_head_border` |
| Cards and panels | `card_bg`, `card_border`, `card_shadow`, `popover_shadow`, `popover_bg`, `card_title` |
| Typography | `font_family`, `font_stylesheet_url`, `heading_font`, `heading_weight`, `page_title`, `label_transform`, `field_label_transform`, `body_text`, `muted_text`, `label_text`, `error_text`, `success_text` |
| Layout and surfaces | `main_bg`, `border_radius`, `border_width`, `color_scheme`, `swatch`, `surface_muted`, `item_hover`, `item_active`, `icon_muted`, `overlay_bg` |
| Feedback | `alert_palette`, `alert_shadow`, `badge_palette`, `badge_dot_palette`, `badge_shape`, `chip`, `danger_item`, `tooltip`, `code_block`, `code_font`, `progress_track`, `pagination_active` |
| Dashboard | `metric_label`, `metric_value`, `metric_icon` |
| Charts | `chart_colors`, `chart_border_color`, `chart_grid_color`, `chart_text_color`, `chart_point_style`, `chart_slice_border_color`, `chart_border_width` |

## `IronAdmin::Configuration::Theme`

| Method | Returns |
|--------|---------|
| `Theme.new(name: :neutral, label: nil)` | A theme with the Neutral values. `label` defaults to the titleized name |
| `#name` | The Symbol the theme is registered under, which is also the value its cookie stores |
| `#label` | The String the theme switcher shows |
| `#dark?` | Whether `color_scheme` is `"dark"` |
| `#popover_background` | `popover_bg`, or `card_bg` while `popover_bg` is empty: the background of floating surfaces |
| `#table_head_divider` | `table_head_border`, or `table_border` while `table_head_border` is empty: the line under a table's header row |
| `#scheme_class` | `"scheme-dark"` for a dark theme, else `"scheme-light"` (`Theme::SCHEME_CLASSES`) |
| `#dup` | A copy whose Arrays and Hashes (`chart_colors`, the palettes) are copies too |

## Configuration

| Method | Description |
|--------|-------------|
| `config.theme { \|t\| ... }` | Yields and returns the default theme: the one `default_theme` names, else Neutral. `config.theme_config` returns the same theme |
| `config.register_theme(name, label: name.to_s.titleize) { \|t\| ... }` | Builds a theme with the pristine Neutral values, yields it, stores it under `name.to_sym` and returns it. Registering a name again replaces the theme. Raises `ArgumentError` for a blank name |
| `config.themes` | `Hash{Symbol => Theme}` of the registered themes, the default theme first, then the others in registration order |
| `config.default_theme` / `config.default_theme = name` | The name of the theme used when a request resolves none (default `:neutral`). The writer raises `ArgumentError` for a blank name |
| `config.theme_resolver { \|request\| ... }` | Sets the block that returns the name (String, Symbol or `nil`) of each request's theme, and returns the resolver. Without a block, it returns the current resolver |
| `config.resolve_theme(request)` | The theme the resolver names; the default theme for an unknown, blank or `nil` name, or when the resolver raises (logged as a warning) |
| `config.theme_for(name)` | The theme registered under `name`, else the default theme |
| `config.find_theme(name)` | The theme registered under `name` (a String or Symbol), else `nil` |

| Constant | Value |
|----------|-------|
| `IronAdmin::Configuration::NEUTRAL_THEME` | `:neutral`, the name of the built-in theme |
| `IronAdmin::Configuration::THEME_COOKIE` | `"iron_admin_theme"`, the cookie the switcher sets |
| `IronAdmin::Configuration::DEFAULT_THEME_RESOLVER` | The resolver used until `theme_resolver` gets a block: it reads `THEME_COOKIE` |

## The theme of a request

| API | Description |
|-----|-------------|
| `IronAdmin.current_theme` | The theme of the current request, or the default theme outside a request. Read it in your own components |
| `IronAdmin::Current.theme` | Where `IronAdmin::ApplicationController` stores the resolved theme, before authentication (`IronAdmin::Current` is an `ActiveSupport::CurrentAttributes`) |
| `IronAdmin.configuration.theme` | The default theme, whatever the request. Use it to configure the theme, not to render |

## Helpers and class recipes

`IronAdmin::ThemeHelper`, available in the engine's views and in views you override:

| Helper | Returns |
|--------|---------|
| `t` | `IronAdmin.current_theme` |
| `cp_btn_primary`, `cp_btn_secondary`, `cp_btn_danger`, `cp_btn_ghost` | A complete 36px button (`cp_btn_primary_lg` and `cp_btn_filter_apply` are the same as `cp_btn_primary`) |
| `cp_input_class(error: false, padding: "px-3")`, `cp_select_class(error: false)`, `cp_textarea_class(error: false)`, `cp_file_input_class(error: false)` | A complete control; `error: true` uses `input_error` |
| `cp_checkbox_class`, `cp_radio_class` | A checkbox or radio button with the engine's check mark or dot |
| `cp_filter_input_class`, `cp_search_class`, `cp_navbar_search_class` | Filter, search and navbar search inputs |
| `cp_card` | `card_bg`, `border_width`, `card_border`, `border_radius` and `card_shadow` |
| `cp_heading` | `heading_weight` with `heading_font`, else `font_family` |
| `cp_badge_count` | A count bubble with `badge_shape` and `badge_count` |
| `cp_link`, `cp_link_muted`, `cp_focus`, `cp_scope_active`, `cp_scope_inactive`, `cp_sidebar_bg`, `cp_sidebar_title`, `cp_sidebar_link`, `cp_sidebar_link_active`, `cp_sidebar_group_label`, `cp_body_text`, `cp_muted_text`, `cp_label_text`, `cp_table_header_bg`, `cp_table_row_hover`, `cp_table_border` | The matching property (`cp_focus` is `input_focus`; `cp_sidebar_link` is `sidebar_link` with `sidebar_link_hover`) |
| `cp_google_fonts?` | Whether `font_stylesheet_url` is on `fonts.googleapis.com` |

`IronAdmin::Form::ControlClasses` builds the controls from a theme, for components of your own:
`button(theme, variant = :primary)` (`:primary`, `:secondary`, `:danger`, `:ghost`; another
variant raises `ArgumentError`), `input(theme, error: false, muted: false, padding: "px-3")`,
`textarea(theme, error: false, muted: false)`, `select(theme, error: false, muted: false)`,
`file_input(theme, error: false)`, `checkbox(theme)` and `radio(theme)`. `muted: true` is a
readonly or disabled control (`surface_muted`).

## Theme switcher

| Part | Description |
|------|-------------|
| `IronAdmin::Layout::ThemeSwitcherComponent` | The navbar disclosure. It renders only with two or more themes |
| `theme_switcher` component slot | Replaces it. Keywords: `themes` (Array, default first), `current_theme`, `current_user` |
| `POST /admin/theme` (`themes#update`, `iron_admin.theme_path`) | Params `theme` and `return_to`. Stores a registered theme in `THEME_COOKIE` and redirects with `303` |
| `cp-disclosure` Stimulus controller | Closes the disclosure on Escape and on outside clicks |
| `iron_admin.theme_switcher.button_label`, `.menu_label`, `.unknown` | Its translations |
