# Building a Custom Adapter

This guide covers everything you need to build a custom IronAdmin adapter from scratch. An adapter enables IronAdmin to work with any data source — a different ORM, a REST API, a flat file, or anything else that can provide records.

## Architecture Overview

Every IronAdmin controller, component, and helper interacts with data exclusively through the adapter. The adapter is the **only** boundary between IronAdmin and your data source.

```
Controller → Resource.adapter → YourAdapter → Your Data Source
```

The adapter is instantiated once per resource class with the model class as its argument:

```ruby
adapter = YourAdapter.new(Product) # Product is your model/data class
adapter.all                        # => returns all records
adapter.find("abc123")             # => returns one record
adapter.filter(scope, :status, "active") # => filtered scope
```

## Quick Start

### 1. Create the adapter class

```ruby
# lib/my_app/iron_admin/sequel_adapter.rb
class MyApp::IronAdmin::SequelAdapter < IronAdmin::Adapters::Base
  # Implement all 36 methods (see reference below)
end
```

### 2. Configure a resource to use it

```ruby
# app/iron_admin/resources/product_resource.rb
module IronAdmin
  module Resources
    class ProductResource < IronAdmin::Resource
      self.adapter_class = MyApp::IronAdmin::SequelAdapter
    end
  end
end
```

You can pass a class directly (as above) or register it in the adapter registry for symbol-based configuration:

```ruby
# config/initializers/iron_admin.rb
IronAdmin::Adapters::Registry::ADAPTERS[:sequel] = {
  require_path: "my_app/iron_admin/sequel_adapter",
  class_name: "MyApp::IronAdmin::SequelAdapter",
}

# Then in resources:
self.adapter_class = :sequel
```

### 3. Create a QueryBuilder (optional but recommended)

If your data source supports operator-based filters (`:string` and `:number` filter types), create a query builder:

```ruby
class MyApp::IronAdmin::SequelQueryBuilder < IronAdmin::Filters::BaseQueryBuilder
  private

  def apply_string_filter
    # Implement contains, equals, starts_with, ends_with
  end

  def apply_number_filter
    # Implement equals, greater_than, less_than, between
  end
end
```

---

## Complete Method Reference

`Adapters::Base` defines 36 methods organized into 8 categories. All methods raise `NotImplementedError` by default except `resource_name` and `human_name` (which use `ActiveModel::Naming`).

### Schema Introspection (8 methods)

These methods let IronAdmin discover your model's structure. `FieldInferrer` calls them to auto-generate field configurations.

#### `columns` → `Array<#name, #type>`

Returns descriptors for every field/column in the model. Each object **must** respond to:

| Method | Return | Example |
|--------|--------|---------|
| `.name` | `String` | `"email"` |
| `.type` | `Symbol` | `:string` |

Valid type symbols (mapped by `FieldInferrer::TYPE_MAP`):

| Symbol | Rendered as |
|--------|------------|
| `:string` | Text input (auto-detects `:url` and `:email` by name pattern) |
| `:text` | Textarea |
| `:integer`, `:float`, `:decimal` | Number input (`:number`) |
| `:boolean` | Checkbox |
| `:date` | Date picker |
| `:datetime` | Datetime picker |
| `:time` | Time input |
| `:json`, `:jsonb` | JSON editor |

Any unrecognized type falls back to `:text`.

**Tip:** Create a `ColumnDescriptor` value object:

```ruby
ColumnDescriptor = Struct.new(:name, :type) do
  def to_s = name
end
```

**Example (Sequel):**

```ruby
def columns
  model_class.db_schema.map do |name, info|
    ColumnDescriptor.new(name.to_s, map_type(info[:type]))
  end
end
```

#### `column_names` → `Array<String>`

Flat list of column/field names as strings.

```ruby
def column_names
  columns.map(&:name)
end
```

#### `has_column?(name)` → `Boolean`

Checks if a column/field exists. Accepts `Symbol` or `String`.

```ruby
def has_column?(name)
  column_names.include?(name.to_s)
end
```

#### `enums` → `Hash{String => Hash}`

Returns enum definitions. The outer key is the column name (String), the inner hash maps enum values to their storage values.

```ruby
# Expected format:
{ "status" => { "active" => 0, "inactive" => 1, "archived" => 2 } }
```

`FieldInferrer` calls `enums.key?(name)` and `enums[name].keys` to generate select fields. Return `{}` if your data source has no enums.

#### `associations(kind = nil)` → `Array<AssociationDescriptor>`

Returns association descriptors, optionally filtered by kind. Each object **must** respond to:

| Method | Return | Notes |
|--------|--------|-------|
| `.name` | `Symbol` | Association name (e.g., `:user`) |
| `.macro` | `Symbol` | `:belongs_to`, `:has_many`, `:has_one`, or `:has_and_belongs_to_many` |
| `.klass` | `Class` | The associated model class |
| `.foreign_key` | `String` | Foreign key column (e.g., `"user_id"`) |
| `.polymorphic?` | `Boolean` | Whether this is a polymorphic association |
| `.foreign_type` | `String` | Polymorphic type column (e.g., `"commentable_type"`) — only called when `polymorphic?` is `true` |

`kind` is one of: `:belongs_to`, `:has_many`, `:has_one`, `:has_and_belongs_to_many`, or `nil` (return all).

**Tip:** Create an `AssociationWrapper` class to normalize your ORM's metadata to this interface.

Return `[]` if your data source has no associations.

#### `association(name)` → `AssociationDescriptor | nil`

Returns a single association descriptor by name, or `nil` if not found.

#### `attachments` → `Hash`

Returns file attachment descriptors. Each value must respond to `.macro` returning `:has_one_attached` or `:has_many_attached`. This is ActiveStorage-specific — return `{}` for non-Rails data sources.

#### `rich_text_attributes` → `Array<Symbol>`

Returns ActionText rich text attribute names. Each name starts with `rich_text_` (e.g., `:rich_text_content`). Return `[]` for non-Rails data sources.

### Naming (3 methods)

#### `resource_name` → `String`

**Implemented in Base.** Returns the URL-friendly plural name (e.g., `"users"`). Uses `model_class.model_name.plural`. Override only if your model doesn't include `ActiveModel::Naming`.

#### `human_name` → `String`

**Implemented in Base.** Returns the human-readable name (e.g., `"User"`). Uses `model_class.model_name.human`. Override only if your model doesn't include `ActiveModel::Naming`.

#### `table_name` → `String | nil`

Returns the storage name (table, collection, endpoint path). Return `nil` if not applicable.

### Query Building (10 methods)

These methods build and manipulate query scopes. A "scope" is any chainable query object — an `ActiveRecord::Relation`, a `Mongoid::Criteria`, or your own query builder.

#### `all` → `Scope`

Returns a base scope representing all records.

#### `find(id)` → `Record`

Finds a record by primary key. **Must raise `IronAdmin::RecordNotFound`** when the record doesn't exist. Wrap your ORM's native not-found exception:

```ruby
def find(id)
  model_class.find(id)
rescue MyOrm::NotFoundError => e
  raise IronAdmin::RecordNotFound, e.message
end
```

#### `find_by(attrs)` → `Record | nil`

Finds a record by attributes hash. Returns `nil` when not found (does **not** raise).

#### `filter(scope, column, value)` → `Scope`

Filters a scope by a column value. Must handle these value types:

| Value type | Expected behavior |
|-----------|-------------------|
| Scalar (String, Integer, etc.) | Exact match |
| `Array` | IN / any-of match |
| `Range` | Between (may be beginless or endless) |

```ruby
def filter(scope, column, value)
  case value
  when Array then scope.where(column => value)     # IN clause
  when Range then scope.where(column => value)     # BETWEEN
  else scope.where(column => value)                # exact match
  end
end
```

#### `order_by(scope, column, direction)` → `Scope`

Orders a scope. `direction` is `:asc` or `:desc`.

#### `limit(scope, max)` → `Scope`

Limits the scope to `max` records.

#### `preload(scope, association_names)` → `Scope`

Eager-loads associations to prevent N+1 queries. `association_names` is an `Array<Symbol>`. If your data source doesn't support eager loading, return the scope unmodified.

#### `distinct_values(column)` → `Array`

Returns sorted, unique, non-nil values for a column. Used to populate filter dropdowns.

#### `pluck(scope, column)` → `Array`

Extracts raw values for a single column from a scope.

#### `count(scope = nil)` → `Integer`

Counts records. When `scope` is `nil`, count all records.

### Search (2 methods)

#### `search_column(scope, column, query)` → `Scope`

Searches a single column for a substring match (case-insensitive). The `query` string comes from user input — **always escape it** to prevent injection:

- SQL: Use parameterized `LIKE`/`ILIKE` with `sanitize_like`
- MongoDB: Use `Regexp.escape` before building regex
- HTTP API: URL-encode the query

#### `search_columns(scope, columns, query)` → `Scope`

Searches multiple columns with OR logic. Same escaping rules apply.

### CRUD (4 methods)

#### `build(attrs = {})` → `Record`

Creates a new unsaved record with the given attributes.

#### `save(record)` → `Boolean`

Persists a record. Returns `true` on success, `false` on validation failure.

#### `update(record, attrs)` → `Boolean`

Updates a record's attributes. Returns `true` on success, `false` on validation failure.

#### `destroy!(record)` → `void`

Permanently deletes a record. Should raise on failure (bang method).

### Transactions (1 method)

#### `transaction(&block)` → `Object`

Wraps a block in an atomic transaction. If your data source doesn't support transactions, simply `yield`:

```ruby
def transaction
  yield
end
```

### Scope Manipulation (1 method)

#### `unscope_column(scope, column)` → `Scope`

Removes a WHERE condition on a specific column from a scope. Used by the soft-delete feature to bypass the default `deleted_at IS NULL` filter.

If your scope object supports `unscope`, use it. Otherwise, rebuild the scope without the column:

```ruby
def unscope_column(scope, column)
  # Rebuild scope excluding the column from conditions
end
```

### Batch (1 method)

#### `find_each(scope, &block)` → `void`

Iterates all records in memory-efficient batches. Used by CSV export. If your data source doesn't support batching, fall back to `.each`:

```ruby
def find_each(scope, &block)
  scope.each(&block)
end
```

### Adapter-Agnostic Interface (5 methods)

These methods bridge differences between ORMs so controllers remain adapter-agnostic.

#### `record_changes(record)` → `Hash`

Returns the changes hash after a save/update operation. Used by audit logging.

| ORM | Implementation |
|-----|---------------|
| ActiveRecord | `record.saved_changes` |
| Mongoid | `record.previous_changes` |
| HTTP API | `{}` (or track changes client-side) |

#### `wrap_rollback(&block)` → `void`

Executes a block and converts `IronAdmin::Rollback` to the adapter-native rollback mechanism. This is called **inside** `transaction`:

```ruby
# Controller does:
adapter.transaction do
  adapter.wrap_rollback do
    # ... action code ...
    raise IronAdmin::Rollback if result == false
  end
end
```

| ORM | Implementation |
|-----|---------------|
| ActiveRecord | Rescue `IronAdmin::Rollback`, re-raise as `ActiveRecord::Rollback` |
| Mongoid | Rescue `IronAdmin::Rollback`, return `nil` |
| No transactions | Rescue `IronAdmin::Rollback`, return `nil` |

#### `query_builder_class` → `Class`

Returns the `BaseQueryBuilder` subclass for operator-based filters (`:string` and `:number` filter types). If you don't support operator filters, create a no-op builder:

```ruby
class NoOpQueryBuilder < IronAdmin::Filters::BaseQueryBuilder
  private

  def apply_string_filter = @scope
  def apply_number_filter = @scope
end
```

#### `pagy_method` → `Symbol`

Returns the Pagy backend method name used for pagination.

| ORM | Value |
|-----|-------|
| ActiveRecord | `:pagy` |
| Mongoid | `:pagy_mongoid` |
| Custom | `:pagy` (default) or implement a custom Pagy backend |

#### `cast_boolean(value)` → `Boolean`

Casts a string form value (`"true"`, `"false"`, `"1"`, `"0"`) to a Ruby boolean. Used by filter params.

---

## QueryBuilder Integration

If your data source supports operator-based string and number filters, create a `BaseQueryBuilder` subclass.

### String operators

| Operator | Behavior |
|----------|----------|
| `contains` | Substring match (case-insensitive) |
| `equals` | Exact match |
| `starts_with` | Prefix match |
| `ends_with` | Suffix match |

### Number operators

| Operator | Behavior |
|----------|----------|
| `equals` | Exact numeric match |
| `greater_than` | Greater than |
| `less_than` | Less than |
| `between` | Range (inclusive, uses `@value` and `@upper_value`) |

### Example (Sequel)

```ruby
class SequelQueryBuilder < IronAdmin::Filters::BaseQueryBuilder
  private

  def apply_string_filter
    return @scope unless STRING_OPS.include?(@op)

    col = ::Sequel[@filter[:name]]
    case @op
    when "contains"    then @scope.where(col.ilike("%#{escape(@value)}%"))
    when "equals"      then @scope.where(@filter[:name] => @value)
    when "starts_with" then @scope.where(col.ilike("#{escape(@value)}%"))
    when "ends_with"   then @scope.where(col.ilike("%#{escape(@value)}"))
    else @scope
    end
  end

  def apply_number_filter
    return @scope unless NUMBER_OPS.include?(@op)

    num = cast_number(@value)
    return @scope unless num

    case @op
    when "equals"       then @scope.where(@filter[:name] => num)
    when "greater_than" then @scope.where { |o| o.send(@filter[:name]) > num }
    when "less_than"    then @scope.where { |o| o.send(@filter[:name]) < num }
    when "between"      then apply_between(num)
    else @scope
    end
  end

  def apply_between(num)
    upper = cast_number(@upper_value)
    return @scope unless upper

    @scope.where(@filter[:name] => num..upper)
  end

  def escape(value)
    value.gsub(/[%_\\]/) { |m| "\\#{m}" }
  end
end
```

The `cast_number` method is inherited from `BaseQueryBuilder` — it handles integer/float parsing and returns `nil` for invalid values.

---

## Testing Your Adapter

Follow the same patterns used by the built-in adapter specs. Your test file should mirror `spec/lib/iron_admin/adapters/active_record_spec.rb`.

### Unit tests with doubles (no database required)

For adapters that wrap an external service or unavailable ORM, use test doubles:

```ruby
RSpec.describe MyAdapter do
  subject(:adapter) { described_class.new(model_class) }

  let(:model_class) do
    double("Model",
      fields: { "name" => double(name: "name", type: String) },
      model_name: double(plural: "products", human: "Product"),
      # ... stub all methods your adapter calls
    )
  end

  describe "#columns" do
    it "returns an array" do
      expect(adapter.columns).to be_an(Array)
    end

    it "returns descriptors with name and type" do
      expect(adapter.columns.first).to respond_to(:name)
      expect(adapter.columns.first).to respond_to(:type)
    end
  end

  describe "#find" do
    it "raises IronAdmin::RecordNotFound for missing records" do
      allow(model_class).to receive(:find).and_raise(SomeNotFoundError)
      expect { adapter.find("bad") }.to raise_error(IronAdmin::RecordNotFound)
    end
  end

  # ... test all 36 methods
end
```

### Integration tests with a real data source

If possible, also test with real data:

```ruby
RSpec.describe MyAdapter, :integration do
  subject(:adapter) { described_class.new(RealModel) }

  describe "#filter" do
    it "filters by exact value" do
      RealModel.create!(name: "Alice", status: "active")
      RealModel.create!(name: "Bob", status: "inactive")
      result = adapter.filter(adapter.all, :status, "active")
      expect(result.count).to eq(1)
    end
  end
end
```

### BetterSpecs conventions

Follow [BetterSpecs](https://www.betterspecs.org/) as required by this project:

- `describe "#method_name"` for each method
- `context "when ..."` for conditional behavior
- One expectation per `it` block
- Use `subject(:adapter)` and `let` for setup
- Meaningful descriptions that read as sentences

### Coverage requirements

SimpleCov enforces **80% minimum per file**. Ensure your adapter and query builder files have adequate test coverage.

---

## Checklist

Use this checklist when building a new adapter:

### Setup
- [ ] Create adapter class inheriting from `IronAdmin::Adapters::Base`
- [ ] Create value objects (`ColumnDescriptor`, `AssociationWrapper`) if needed
- [ ] Create `QueryBuilder` subclass (or use `NoOpQueryBuilder`)

### Schema Introspection
- [ ] `columns` — returns `Array<#name, #type>` with valid type symbols
- [ ] `column_names` — returns `Array<String>`
- [ ] `has_column?(name)` — handles both Symbol and String input
- [ ] `enums` — returns `Hash{String => Hash}` or `{}`
- [ ] `associations(kind)` — returns filtered `Array<AssociationDescriptor>` or `[]`
- [ ] `association(name)` — returns descriptor or `nil`
- [ ] `attachments` — returns `Hash` or `{}`
- [ ] `rich_text_attributes` — returns `Array<Symbol>` or `[]`

### Naming
- [ ] `table_name` — returns `String` or `nil`
- [ ] Verify `resource_name` and `human_name` work (inherited from Base)

### Query Building
- [ ] `all` — returns a chainable scope
- [ ] `find(id)` — raises `IronAdmin::RecordNotFound` on miss
- [ ] `find_by(attrs)` — returns `nil` on miss (does not raise)
- [ ] `filter(scope, column, value)` — handles scalars, Arrays, and Ranges
- [ ] `order_by(scope, column, direction)` — `:asc` and `:desc`
- [ ] `limit(scope, max)` — returns limited scope
- [ ] `preload(scope, names)` — eager loads or returns scope unchanged
- [ ] `distinct_values(column)` — sorted, compact, unique
- [ ] `pluck(scope, column)` — raw column values
- [ ] `count(scope)` — defaults to `all` when scope is `nil`

### Search
- [ ] `search_column(scope, column, query)` — case-insensitive, escaped
- [ ] `search_columns(scope, columns, query)` — OR logic across columns

### CRUD
- [ ] `build(attrs)` — unsaved record
- [ ] `save(record)` — returns boolean
- [ ] `update(record, attrs)` — returns boolean
- [ ] `destroy!(record)` — raises on failure

### Transactions & Scope
- [ ] `transaction(&block)` — atomic or yield
- [ ] `unscope_column(scope, column)` — removes condition
- [ ] `find_each(scope, &block)` — batched or `.each`

### Adapter-Agnostic
- [ ] `record_changes(record)` — returns changes hash
- [ ] `wrap_rollback(&block)` — catches `IronAdmin::Rollback`
- [ ] `query_builder_class` — returns your QueryBuilder subclass
- [ ] `pagy_method` — returns `:pagy` or custom
- [ ] `cast_boolean(value)` — string to boolean

### Testing
- [ ] Unit specs for all 36 methods
- [ ] Edge cases: nil values, empty arrays, missing records
- [ ] `find` raises `IronAdmin::RecordNotFound`
- [ ] `find_by` returns `nil` (not raises)
- [ ] QueryBuilder specs for all operators
- [ ] 80%+ coverage per file

### Documentation
- [ ] Update `CHANGELOG.md` under `[Unreleased]`
- [ ] Update `docs/guides/extending.md` if adding a built-in adapter
- [ ] Add setup instructions for the new data source

---

## Reference: Built-in Adapters

| Adapter | Data source | Key differences |
|---------|-------------|----------------|
| `ActiveRecord` | SQL databases (PostgreSQL, MySQL, SQLite) | Uses `LIKE`/`ILIKE` for search, `ActiveRecord::Base.transaction`, `scope.unscope(where:)` |
| `Mongoid` | MongoDB | Uses `$regex` for search, `scope.any_of` for OR, `scope.in` for arrays, `scope.selector` for unscope |

Study `lib/iron_admin/adapters/active_record.rb` (simplest) and `lib/iron_admin/adapters/mongoid.rb` (most complex) as reference implementations.
