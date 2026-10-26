# Export

IronAdmin provides built-in CSV and JSON export.

## Enabling Export

Enabled by default with CSV and JSON:

```ruby
class UserResource < IronAdmin::Resource
  exports :csv, :json
end
```

Only CSV:

```ruby
class UserResource < IronAdmin::Resource
  exports :csv
end
```

Disable:

```ruby
class SecretResource < IronAdmin::Resource
  exports
end
```

A format the resource does not enable returns `404`.

## Custom Export Fields

```ruby
class UserResource < IronAdmin::Resource
  export_fields :id, :name, :email, :role, :created_at
end
```

Columns follow the order of `export_fields`. Without `export_fields`, every field is exported
except `:password` and `:hidden` fields. A `:hidden` field listed in `export_fields` is exported
with its value. A `:password` field listed there is exported as `[FILTERED]`, never with its
value. Fields hidden from the current user are always left out.

## Export URL

```
GET /admin/:resource_name/export?format=csv
GET /admin/:resource_name/export?format=json
```

Exports respect the current scope, filters, search query and sort: rows come in the same order
as on the index page (`sort`/`direction`, or `config.default_sort`), in CSV and JSON alike.

## Values

- Dates and times export in ISO 8601, and booleans as `Yes` or `No`.
- `belongs_to` fields export the associated record's label: its `display` option, or its
  `name`, `title`, `email`, `label` or `slug`.
- `:file` fields export the attached file's name, and `:files` fields export the names of all
  attached files: a JSON array, or a comma-separated CSV cell. Both are blank when nothing is
  attached.
- `:rich_text` fields export the stored HTML, without the ActionText layout around it.
- In CSV, cells that start with `=`, `+`, `-`, `@`, a tab or a carriage return get a leading
  `'`, so spreadsheet apps do not evaluate them as formulas.
