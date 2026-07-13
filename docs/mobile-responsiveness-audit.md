# Mobile Responsiveness Audit

Roadmap item: **"Improve mobile responsiveness"** — audit and polish the IronAdmin
engine UI on small viewports (index, show, forms, filters, sidebar, dashboards,
action/import flows).

> **Verification caveat:** This audit is based on reading the HAML markup and Tailwind
> breakpoint structure. No visual browser rendering was performed in this environment.
> Items flagged "needs visual check" below should be confirmed by the maintainer on a
> real device/emulator.

## Method

Reviewed every template in `app/components/iron_admin/` (especially `layout/`) and
`app/views/iron_admin/`, looking for: fixed-width containers with no mobile collapse,
tables without horizontal scroll, forms/filters that overflow, cramped button rows, and
oversized fixed padding.

Theme-driven classes (`lib/iron_admin/configuration/theme.rb`) were left overridable —
responsive/layout utilities were added around them, not baked into theme values.

## Findings and fixes

| # | Problem | Location (before) | Fix applied |
|---|---------|-------------------|-------------|
| 1 | **Sidebar never collapses.** `<nav>` is a fixed `w-64` column always present in the shell flex row. On phones it consumes 16rem of the viewport with no way to hide it, and there is no hamburger toggle. This is the biggest mobile defect. | `layout/sidebar_component.html.haml:1`, `layout/shell_component.html.haml:1-2`, `layout/navbar_component.html.haml:1` | Sidebar `<nav>` is now `fixed inset-y-0 left-0 z-40 -translate-x-full transition-transform lg:static lg:translate-x-0` — an off-canvas drawer on mobile, static on desktop. Added a `cp-sidebar` Stimulus controller (`open`/`close`/`toggle`/`closeOnEscape`), a hamburger button in the navbar (`lg:hidden`), a `lg:hidden` backdrop in the shell that closes on tap, and a close button inside the drawer. Escape closes the drawer. |
| 2 | **Oversized fixed page padding.** Every top-level view uses `.p-8` (2rem all around), wasting horizontal space on small screens. | `resources/{index,show,new,edit,action_form}.html.haml`, `imports/{new,preview}.html.haml`, `audit/index.html.haml`, `search/index.html.haml`, `tools/{show,action_form}.html.haml` | Replaced `.p-8` with `.p-4.sm:p-6.lg:p-8` (0.75rem on mobile, scaling up). |
| 3 | **Data tables without horizontal scroll.** Several tables render `min-w-full` with no scroll wrapper, so wide tables overflow the viewport and push the page horizontally. (The main index table already had `overflow-x-auto`.) | `dashboards/recent_table_component.html.haml`, `resources/related_list_component.html.haml`, `resources/data_table_component.html.haml`, `audit/index.html.haml` table | Wrapped each table in `.overflow-x-auto`. |
| 4 | **Show-page detail rows cramped.** Definition rows use `flex items-center` with hardcoded `w-1/3` / `w-2/3`, giving the value only a third of an already-narrow screen. | `resources/show.html.haml` (main `<dl>` and has_one assoc `<dl>`) | Rows now `flex flex-col gap-1 sm:flex-row sm:items-center`; widths gated to `sm:w-1/3` / `sm:w-2/3`; added `break-words` to values. Labels stack above values on mobile. |
| 5 | **Header rows overflow.** `flex items-center justify-between` header rows (title + action buttons) don't wrap, so buttons can overflow or squeeze the title. | `resources/index.html.haml`, `resources/show.html.haml`, `imports/preview.html.haml` | Added `gap-3 flex-wrap` to header rows and `flex-wrap` to button groups (show actions, show header actions). |
| 6 | **Scope tabs overflow.** Scope/tab row (`flex gap-1 border-b`) has no scroll; many scopes overflow horizontally. | `resources/index.html.haml` | Added `overflow-x-auto` to the tab strip and `whitespace-nowrap` to each tab so they scroll instead of wrapping/clipping; the scope+search row now `flex-wrap`. |
| 7 | **Audit filter row cramped.** Filter form is `flex gap-4 items-end` with four `flex-1` selects + buttons on one line — unusable on a phone. | `audit/index.html.haml` | Now `flex flex-col gap-4 sm:flex-row sm:items-end` — stacks vertically on mobile, row layout at `sm`. |

## Areas reviewed and already responsive (no change)

- **Edit/new form grid** (`resources/_form.html.haml`): `grid-cols-1 md:grid-cols-2 2xl:grid-cols-3` — already stacks on mobile.
- **Dashboard grids** (`dashboard/index.html.haml`): metrics `grid-cols-1 md:grid-cols-2 lg:grid-cols-4`, charts `grid-cols-1 lg:grid-cols-2` — already responsive.
- **Modal** (`ui/modal_component`): panel is `w-full max-w-*` inside `p-4`, so `w-full` wins on small screens — acceptable.
- **Filters dropdown** (`resources/index.html.haml` / `filters/bar_component`): `absolute right-0 w-72` popover — anchored to the right edge, fits ≥ 320px viewports.
- **HABTM / tags / import field chips**: already use `flex flex-wrap gap-*`.

## Not applied (proposals for follow-up)

- **Card-based table layout on mobile.** `overflow-x-auto` (fix #3) keeps tables usable but still requires horizontal scrolling for wide resources. A more polished pattern is a stacked "label: value" card view below `sm`. Deferred: it is a larger redesign, would need per-column priority hints, and risks regressing the desktop table. Flagged rather than applied to keep this change additive.
- **Navbar user label** stays visible on all sizes; could be hidden below `sm` if space is tight. Left as-is (low impact).
- **Bulk-actions bar** button group (`resources/index.html.haml`) could wrap on very small screens; low priority since it only appears after selection.

## Needs visual verification by maintainer

- Off-canvas drawer open/close animation, backdrop, and Escape/close behaviors on a real phone, including rotating mobile→desktop while the drawer is open (Tailwind `lg:translate-x-0` should force it back visible).
- That the hamburger toggle is reachable and the drawer overlays content with correct z-index against sticky table columns (`sticky right-0 z-10`).
- Horizontal-scroll tables feel usable (no double scrollbars, no body horizontal scroll).
- Show-page stacked rows and stacked audit filters look balanced at 320–414px widths.

## Test / lint results

- `bundle exec rspec` — full suite passing, 0 failures.
- `bundle exec rubocop` — 0 offenses.
