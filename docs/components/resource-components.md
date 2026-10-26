# Resource Components

Components for displaying and managing resource data.

## DataTableComponent

Sortable data table with records.

```ruby
IronAdmin::Resources::DataTableComponent.new(
  records: @users,                # Required: collection of records
  fields: fields,                 # Required: array of Field objects
  resource_class: UserResource,   # Required: resource class
  base_url: "/admin/users?",      # Required: base URL for sort links
  current_sort: nil,              # Optional: current sort column
  current_direction: nil          # Optional: current sort direction ("asc"/"desc")
)
```

**Example:**

```haml
= render IronAdmin::Resources::DataTableComponent.new(
  records: @users,
  fields: UserResource.resolved_fields.first(5),
  resource_class: UserResource,
  base_url: request.fullpath.split("?").first + "?",
  current_sort: params[:sort],
  current_direction: params[:direction]
)
```

The component appends `sort=<column>&direction=<asc|desc>` to `base_url`. Its sort links have
`data-turbo-frame="_top"`, so a click loads the whole page and the search and filter forms
outside the `records` Turbo frame pick up the new sort. When IronAdmin renders it in the
`table` slot, the `base_url` it passes already keeps the scope, the search query and the
active filters (see [Components](../guides/components.md#slots)).

---

## ShowFieldComponent

Display a single field value (dt/dd format).

```ruby
IronAdmin::Resources::ShowFieldComponent.new(
  field: field,      # Required: Field object
  record: @user      # Required: record to display
)
```

**Example:**

```haml
%dl
  - @fields.each do |field|
    = render IronAdmin::Resources::ShowFieldComponent.new(
      field: field,
      record: @user
    )
```

---

## ActionsComponent

Custom actions for a record.

```ruby
IronAdmin::Resources::ActionsComponent.new(
  actions: actions,              # Required: array of action hashes
  record: @user,                 # Required: record for actions
  resource_class: UserResource   # Required: resource class
)
```

**Action hash structure:**

```ruby
{
  name: :archive,
  label: "Archive",
  icon: "archive-box",
  confirm: true,
  confirm_message: "Archive this user?"   # Optional: text of the confirmation dialog
}
```

With `confirm: true`, the button asks for confirmation with the action's `confirm_message`,
or with `iron_admin.resources.action.confirm` ("Are you sure?") when it has none.

The component renders every action it is given. On the show page, IronAdmin sets
`@member_actions` to the actions it would run for that record: allowed by the resource
policy, able to load the record (a soft-deleted record only offers `restore`), and with a
passing `condition`. Pass that list instead of `defined_actions` in a custom show view.

**Example:**

```haml
= render IronAdmin::Resources::ActionsComponent.new(
  actions: @member_actions,
  record: @record,
  resource_class: @resource_class
)
```

---

## BreadcrumbComponent

Navigation breadcrumbs.

```ruby
IronAdmin::Resources::BreadcrumbComponent.new
```

**Slots:**
- `items` - Breadcrumb items (renders `ItemComponent`)

**ItemComponent options:**
- `label` - Display text
- `href` - Link URL (optional)
- `current` - Mark as current page (no link, aria-current)

**Example:**

```haml
= render IronAdmin::Resources::BreadcrumbComponent.new do |breadcrumb|
  - breadcrumb.with_item(label: "Dashboard", href: dashboard_path)
  - breadcrumb.with_item(label: "Users", href: users_path)
  - breadcrumb.with_item(label: @user.name, current: true)
```

---

## BulkActionsComponent

Actions for selected records.

```ruby
IronAdmin::Resources::BulkActionsComponent.new(
  actions: bulk_actions,         # Required: array of bulk action hashes
  resource_class: UserResource   # Required: resource class
)
```

**Example:**

```haml
= render IronAdmin::Resources::BulkActionsComponent.new(
  actions: UserResource.defined_bulk_actions,
  resource_class: UserResource
)
```

---

## RelatedListComponent

Display has_many associations. Show pages render one per `has_many` association of the
resource.

```ruby
IronAdmin::Resources::RelatedListComponent.new(
  association: association,      # Required: association hash
  records: @user.posts,          # Required: related records
  limit: 20,                     # Optional: max records to show
  parent: @user                  # Optional: record that owns the association
)
```

**Association hash structure:**

```ruby
{
  name: :posts,
  resource: PostResource,
  display: :title,
  reflection: User.reflect_on_association(:posts)  # Optional: used with parent: for "View all"
}
```

`Resource.has_many_associations` returns hashes in this shape, `reflection:` included.

The list renders nothing when there are no records. The card has no border, rows are divided
with `theme.table_border`, the table scrolls horizontally inside an `overflow-x-auto`
container, and the "View all" label comes from `iron_admin.resources.show.view_all`.

**"View all" link:** by default it opens the associated resource's index. With `parent:` and
a `reflection:`, it opens the index filtered by the parent's foreign key, but only when the
associated resource has a filter on that column (for example `filter :user_id, type: :select`
in `PostResource`; integer `_id` columns get no inferred filter). A `:select` filter (or a
custom filter type) gets the parent's id (`filters[user_id]=42`), and a `:string` or
`:number` filter gets `op: equals` with the id. Through associations, polymorphic (`as:`)
associations, `:boolean` and `:date_range` filters, and resources without such a filter keep
the plain index link.

**Example:**

```haml
-# In a show view: @resource_class is OrderResource and @record the order
- association = @resource_class.has_many_associations.find { |assoc| assoc[:name] == :line_items }
= render IronAdmin::Resources::RelatedListComponent.new(
  association: association,
  records: @record.line_items,
  limit: 10,
  parent: @record
)
```
