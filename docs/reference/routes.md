# Routes Reference

Mount: `mount IronAdmin::Engine => "/admin"`

## Routes

| Method | Path | Action | Description |
|--------|------|--------|-------------|
| GET | `/admin` | `dashboard#index` | Dashboard |
| GET | `/admin/search?q=...` | `search#index` | Global search |
| GET | `/admin/:resource/export` | `exports#show` | Export |
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

## Query Parameters (Index)

| Param | Example |
|-------|---------|
| `q` | `?q=john` |
| `scope` | `?scope=admins` |
| `sort` | `?sort=name` |
| `direction` | `?direction=asc` |
| `page` | `?page=2` |
| `filter[column]` | `?filter[role]=admin` |
