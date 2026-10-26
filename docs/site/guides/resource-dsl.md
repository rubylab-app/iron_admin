---
title: Resource DSL
parent: Guides
nav_order: 1
permalink: /guides/resource-dsl/
---

# Resource DSL
{: .no_toc }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

Resources are the core building block of IronAdmin. Each resource maps to a model
(ActiveRecord or Mongoid) and defines how it appears in the admin panel.

## Generating a Resource

```bash
rails generate iron_admin:resource User
```

Creates `app/iron_admin/resources/user_resource.rb`:

```ruby
module IronAdmin
  module Resources
    class UserResource < IronAdmin::Resource
    end
  end
end
```

Resources live under the `IronAdmin::Resources` namespace — that is what the
generator creates and what the engine's autoloader expects. **The examples
below show only the class body for brevity; wrap each one in the same
`module IronAdmin; module Resources; … end; end` nesting shown above.**

By convention, `UserResource` maps to the `User` model. To override:

```ruby
class UserResource < IronAdmin::Resource
  self.model_class_override = Account
end
```

## Fields

Fields are automatically inferred from the database schema. Override specific fields:

```ruby
class UserResource < IronAdmin::Resource
  field :status, type: :badge, colors: { active: :green, suspended: :red }
  field :bio, type: :textarea
  field :role, type: :select, choices: %w[user admin]
  field :secret, visible: false
  field :email, readonly: true
  field :admin_notes, visible: ->(user) { user.admin? }
  field :salary, readonly: ->(user) { !user.admin? }
end
```

### Field Options

| Option | Type | Description |
|--------|------|-------------|
| `type` | Symbol | Field type (`:text`, `:textarea`, `:number`, `:boolean`, `:date`, `:datetime`, `:select`, `:badge`, `:json`, `:belongs_to`) |
| `visible` | Boolean/Proc | Show or hide the field. Proc receives current user |
| `readonly` | Boolean/Proc | Make field read-only. Proc receives current user |
| `colors` | Hash | Badge color mapping (for `:badge` type) |
| `choices` | Array | Options for `:select` type |

### Controlling Field Visibility per View

```ruby
class UserResource < IronAdmin::Resource
  index_fields :id, :name, :email, :role, :created_at
  form_fields :role, :name, :email
  export_fields :id, :name, :email, :role
end
```

Each list sets both the fields and their order. Here the form shows Role first, then Name and
Email, even though the table defines `name`, `email` and `role` in that order. Names that do
not resolve to a field (for example a has_many such as `:comments`) are ignored.

## Search

```ruby
class UserResource < IronAdmin::Resource
  searchable :name, :email
end
```

If not specified, all `string` and `text` columns are searchable (excluding `*_digest`
columns).

### Advanced Search Syntax

IronAdmin supports field-specific search queries:

```
email:john@example.com     # Search email field only
name:John                  # Search name field only
role:admin                 # Search role field only
```

Date range search:

```
created_at:2025-01-01..2025-12-31    # Records created in 2025
created_at:2025-06-01..              # Records from June 2025 onwards
created_at:..2025-06-30              # Records before July 2025
```

Search respects field visibility - users cannot search fields they don't have permission
to see. Fields declared `type: :password` or `type: :hidden` are never searched, by the search
box, a `field:value` query, global search or autocomplete, even when `searchable` lists them,
and `sort` on such a column falls back to the default order. Otherwise their values could be
probed one character at a time.

## Filters

```ruby
class UserResource < IronAdmin::Resource
  filter :role, type: :select, options: User.roles.keys
  filter :created_at, type: :date_range
  filter :email_verified, type: :boolean
end
```

A declared `filter` replaces the auto-inferred filter of the same name, so a column never gets
two filters. The index shows the inferred filters first, then the declared ones in the order
they are declared. A `:select` filter without `options` offers the enum values when the column
is an enum, and the column's distinct values otherwise, so `filter :role, type: :select` on an
enum is enough.

Remove a filter, whether declared or auto-inferred:

```ruby
remove_filter :some_column
```

Fields declared `type: :password`, `type: :hidden` or `visible: false` never get an inferred
filter, so their values cannot be probed with filter queries. To filter on a `:password` or
`:hidden` field anyway, declare the filter explicitly. Filters follow field visibility: a filter
on a field the current user cannot see is neither shown nor applied, so a filter declared on a
`visible: false` field never takes effect.

### Filter Types

| Type | Description |
|------|-------------|
| `:select` | Dropdown with choices |
| `:date_range` | Date range picker |
| `:boolean` | True/false toggle |
| `:string` | Text input with operator dropdown (contains, equals, starts_with, ends_with) |
| `:number` | Number input with operator dropdown (equals, greater_than, less_than, between) |

### String and Number Filters

String and number filters provide an operator dropdown alongside the input:

```ruby
class ProductResource < IronAdmin::Resource
  filter :name, type: :string       # contains, equals, starts_with, ends_with
  filter :price, type: :number      # equals, greater_than, less_than, between
end
```

**Auto-inference:** String and text columns automatically infer as `:string` filters.
Integer, float, and decimal columns automatically infer as `:number` filters, except integer
columns ending in `_id`. You only need explicit declarations to override defaults or add
filters for columns that aren't auto-detected.

### Auto-Generated Enum Filters

If your model uses Rails enums, IronAdmin automatically creates select filters:

```ruby
# app/models/order.rb
class Order < ApplicationRecord
  enum :status, { pending: 0, processing: 1, shipped: 2, delivered: 3 }
end

# No filter definition needed - auto-generated from enum
class OrderResource < IronAdmin::Resource
end
```

The filter will display with humanized labels (Pending, Processing, Shipped, Delivered).
Declaring `filter :status, type: :select` as well is harmless: it replaces the inferred filter
and takes the enum values when it has no `options`.

## Scopes

Scopes are predefined query filters shown as tabs:

```ruby
class UserResource < IronAdmin::Resource
  scope :all, -> { all }, default: true
  scope :admins, -> { where(role: :admin) }
  scope :recent, -> { where("created_at > ?", 7.days.ago) }
  scope :locked, -> { where.not(locked_at: nil) }
end
```

## Soft Delete Support

IronAdmin auto-detects models with a `deleted_at` column and provides:

- **Auto-registered scopes**: `with_deleted` and `only_deleted`
- **Auto-registered restore action**: Restores soft-deleted records

```ruby
# If your model has deleted_at column, these are auto-registered:
class PostResource < IronAdmin::Resource
  # Auto: scope :with_deleted, -> { unscoped }
  # Auto: scope :only_deleted, -> { only_deleted }
  # Auto: action :restore { |r| r.update(deleted_at: nil) }
end
```

Works with gems like `paranoia`, `discard`, or custom soft delete implementations.

Restore saves the record with its validations. If they fail, the record stays deleted and the
show page says "Action was not completed" followed by the validation errors.

## Actions

### Record Actions

```ruby
class UserResource < IronAdmin::Resource
  action :lock, icon: "lock-closed", confirm: true do |record|
    record.update!(locked_at: Time.current)
  end

  action :send_reset, icon: "envelope" do |record|
    AuthMailer.password_reset(record).deliver_later
  end

  action :purge_sessions, confirm: true, confirm_message: "Sign this user out everywhere?" do |record|
    record.sessions.delete_all
  end
end
```

With `confirm: true`, the button asks for confirmation first. The dialog shows the action's
`confirm_message`, or `iron_admin.resources.action.confirm` ("Are you sure?") when it has none.

The show page lists the actions the current user can run on that record: the ones the policy
allows, whose `condition` passes, and that can load the record. On a soft-deleted record
hidden by a default scope, only `restore` is offered.

Actions are wrapped in database transactions. Return `false` to rollback (use `next`, not
`return`, to leave the block early):

```ruby
action :process do |record|
  next false unless record.can_process?
  record.process!
end
```

When the block returns `false`, or raises `ActiveRecord::Rollback`, nothing is saved or
audited, and the show page says "Action was not completed"
(`iron_admin.resources.action.not_completed`), followed by the record's errors when it has
any. A bulk action that returns `false` shows "Bulk action was not completed"
(`iron_admin.resources.bulk_action.not_completed`) on the index.

### Action Forms

Actions can collect user input before executing by specifying `form_fields:`. The form is
displayed in a modal when the action is triggered.

```ruby
class OrderResource < IronAdmin::Resource
  action :reject,
    form_fields: [
      action_field(:reason, type: :textarea, required: true),
      action_field(:notify_customer, type: :boolean, default: true)
    ] do |record, params|
      record.reject!(reason: params[:reason])
      Mailer.rejection(record).deliver_later if params[:notify_customer]
    end
end
```

**ActionField types:** `text`, `textarea`, `number`, `boolean`, `date`, `datetime`,
`select`.

ActionField options:

| Option | Type | Description |
|--------|------|-------------|
| `type` | Symbol | Input type (see list above) |
| `required` | Boolean | Whether the field must be filled |
| `default` | Object | Default value for the input |
| `options` | Array | Options for `:select` type |

Action forms work with both record actions and bulk actions. After Execute, the browser goes
to the record (or, for a bulk action, back to the index) and shows the result as a flash
message.

### Bulk Actions

```ruby
class UserResource < IronAdmin::Resource
  bulk_action :delete_many do |records|
    records.each(&:destroy!)
  end

  bulk_action :lock_all do |records|
    records.update_all(locked_at: Time.current)
  end
end
```

Bulk actions validate that all selected records are accessible to the current user
(respecting tenant scope). After a bulk action, the index comes back with the scope, search,
filters, sort and page it was run from.

## CRUD Restrictions

```ruby
class AuditLogResource < IronAdmin::Resource
  deny_actions :create, :update, :destroy
end
```

`deny_actions` maps controller names to CRUD actions: `:delete` blocks destroy, `:new` blocks
create (and imports), `:edit` blocks update, and `:index` or `:show` blocks every read of the
resource, which also hides it from the sidebar and global search. Denied actions also hide
their buttons.

## Associations

```ruby
class UserResource < IronAdmin::Resource
  has_many :licenses, display: :license_key
  has_many :subscriptions
  belongs_to :organization
  has_one :profile
end
```

The show page lists the first 20 records of each `has_many` association, with a "View all"
link to the associated resource's index. To make that link open the index filtered to the
parent's records, declare a filter on the foreign key in the associated resource:

```ruby
class LicenseResource < IronAdmin::Resource
  filter :user_id, type: :select
end
```

Without such a filter, and for `through:` and polymorphic (`as:`) associations, "View all"
opens the unfiltered index.

### Polymorphic Associations

IronAdmin auto-detects polymorphic `belongs_to` associations. You can also declare them
explicitly with the `types` option to specify which models are allowed:

```ruby
class CommentResource < IronAdmin::Resource
  belongs_to :commentable, polymorphic: true, types: [Article, Photo, Video]
end
```

On forms, a type selector dropdown and an ID selector are rendered. On show and index
pages, the associated record is displayed as a linked reference (e.g., "Article #42").

The `FieldInferrer` automatically detects polymorphic associations when a model has
`*_type` and `*_id` column pairs and creates a `:polymorphic_belongs_to` field type.

### HABTM Associations

`has_and_belongs_to_many` associations are supported with a checkbox UI on forms and badge
display on show pages:

```ruby
class ArticleResource < IronAdmin::Resource
  has_and_belongs_to_many :tags
end
```

### Association Preloading

IronAdmin automatically preloads associations to prevent N+1 queries:

- `belongs_to` associations shown in index are preloaded
- Related records displayed on show pages are preloaded
- Custom preloads can be added:

```ruby
class OrderResource < IronAdmin::Resource
  preload :customer, :line_items, :shipping_address
end
```

### Large Association Handling

For `belongs_to` fields with many options, opt in to an autocomplete component
(instead of loading every record into a dropdown) with `autocomplete: true`:

```ruby
class OrderResource < IronAdmin::Resource
  field :customer_id, type: :belongs_to,
        association: :customer,
        display: :name,
        autocomplete: true
end
```

## Nested Forms

For `has_many` and `has_one` associations, you can enable inline nested editing directly on
the parent form. The model must declare `accepts_nested_attributes_for` for the association.

```ruby
class OrderResource < IronAdmin::Resource
  # has_many with nested editing
  has_many :line_items, nested: true, allow_destroy: true

  # Explicit field selection
  has_many :addresses, nested: true, fields: [:street, :city, :zip]

  # With drag-and-drop ordering (via Stimulus)
  has_many :sections, nested: true, position_field: :position

  # has_one nested
  has_one :profile, nested: true
end
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `nested` | `false` | Enable inline nested form for the association |
| `allow_destroy` | `true` | Allow removing child records from the form |
| `fields` | auto-inferred | Explicit list of child fields to display (excludes `id`, timestamps, and FK by default) |
| `position_field` | `nil` | Column name for drag-and-drop reordering |

Nested forms use the existing `create` and `update` endpoints -- no additional routes are
required. Child attributes are submitted as standard Rails nested attributes
(`*_attributes` params).

## Menu Configuration

```ruby
class UserResource < IronAdmin::Resource
  menu priority: 1, icon: "users", group: "People"
end
```

## Exports

```ruby
class UserResource < IronAdmin::Resource
  exports :csv, :json
  export_fields :id, :name, :email, :role, :created_at
end
```

Exports respect:
- Tenant scoping (if configured)
- Field visibility (users only see fields they have permission to view)
- Current filters and search query
- The index sort order (`sort`/`direction`, or `config.default_sort`), for CSV and JSON alike

Columns follow the order of `export_fields`. Without `export_fields`, every visible field except
`:password` and `:hidden` fields is exported. A `:hidden` field listed in `export_fields` is
exported with its value; a `:password` field listed there is exported as `[FILTERED]`. `exports :csv` limits the formats, and a bare `exports` turns exports off; a
format that is not enabled returns `404`.

See [Imports & Exports]({% link imports-exports.md %}) for more.

## Policies

```ruby
class UserResource < IronAdmin::Resource
  policy do
    allow :read, :update
    deny :destroy, if: ->(user) { !user.superadmin? }
  end
end
```

See [Authorization]({% link authorization.md %}) for details.

## Component Overrides

Replace the index table, the new/edit form, the filter bar or the search box of this
resource with your own ViewComponent:

```ruby
class UserResource < IronAdmin::Resource
  component :table, CustomUserTableComponent
  component :form, "CustomUserFormComponent"
end
```

The valid slots are `:table`, `:form`, `:filter_bar` and `:search`; any other name raises
`ArgumentError`. A resource override wins over a global one in `config.components`. See
the [components guide](https://github.com/rubylab-app/iron_admin/blob/main/docs/guides/components.md#overriding-components)
for the keyword arguments each slot passes.
