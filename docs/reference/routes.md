# Routes Reference

Mount: `mount IronAdmin::Engine => "/admin"`

## Routes

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| GET | `/admin` | `dashboard#index` | Dashboard |
| GET | `/admin/search?q=...` | `search#index` | Global search |
| GET | `/admin/:resource/export` | `exports#show` | Export |
| GET | `/admin/:resource/import` | `imports#new` | Import upload form |
| POST | `/admin/:resource/import/preview` | `imports#preview` | Import preview |
| POST | `/admin/:resource/import` | `imports#create` | Import the previewed file |
| GET | `/admin/:resource` | `resources#index` | List |
| GET | `/admin/:resource/new` | `resources#new` | New form |
| GET | `/admin/:resource/:id` | `resources#show` | Show |
| GET | `/admin/:resource/:id/edit` | `resources#edit` | Edit form |
| POST | `/admin/:resource` | `resources#create` | Create |
| PATCH | `/admin/:resource/:id` | `resources#update` | Update |
| DELETE | `/admin/:resource/:id` | `resources#destroy` | Delete |
| GET | `/admin/:resource/:id/actions/:name/form` | `resources#action_form` | Action form |
| POST | `/admin/:resource/:id/actions/:name` | `resources#execute_action` | Custom action |
| GET | `/admin/:resource/bulk_actions/:name/form` | `resources#bulk_action_form` | Bulk action form |
| POST | `/admin/:resource/bulk_actions/:name` | `resources#execute_bulk_action` | Bulk action |

### Tool Routes

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| GET | `/admin/tools/:tool_name` | `tools#show` | Tool page |
| GET | `/admin/tools/:tool_name/:action_name/form` | `tools#action_form` | Tool action form |
| POST | `/admin/tools/:tool_name/:action_name` | `tools#execute` | Execute tool action |

## Query Parameters (Index)

| Param | Example |
|-------|---------|
| `q` | `?q=john` |
| `scope` | `?scope=admins` |
| `sort` | `?sort=name` |
| `direction` | `?direction=asc` |
| `page` | `?page=2` |
| `filters[column]` | `?filters[role]=admin` (select and boolean filters) |
| `filters[column][op]`, `filters[column][value]`, `filters[column][value_2]` | `?filters[name][op]=contains&filters[name][value]=ann` (string and number filters) |
| `filters[column_from]`, `filters[column_to]` | `?filters[created_at_from]=2026-01-01` (date range filters) |

Sorting keeps the scope, search query and filters, and starts again at page 1. Searching and
filtering keep the sort. HTML requests that end in `403` or `404` render an error page inside
the admin layout; other formats get the bare status.
