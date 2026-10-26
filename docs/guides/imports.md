# Imports

IronAdmin can create and update records from CSV and JSON files. Admins upload a file, check
a preview, and then import it.

## Enabling Imports

Imports are off by default. Enable them per resource with the formats to accept:

```ruby
class UserResource < IronAdmin::Resource
  imports :csv, :json
end
```

The index page then shows an Import button to users the resource lets create records. Imports
follow the `:create` permission: a policy that does not allow `:create`, or
`deny_actions :create` (or `:new`), hides the button and makes the import pages return `403`.

## Import Options

```ruby
class UserResource < IronAdmin::Resource
  imports :csv
  import_fields :email, :name, :role          # Columns that can be imported
  import_upsert_key :email                    # Update the record with the same email
  import_options max_rows: 1_000, preview_rows: 10

  import_transform do |attributes, context|
    attributes.merge(invited_by_id: context.current_user.id)
  end

  import_validate do |attributes|
    "Role is not allowed" if attributes[:role] == "superadmin"
  end
end
```

| Method | Description |
|--------|-------------|
| `imports :csv, :json` | Formats the upload form accepts |
| `import_fields` | Fields a file can set. By default, every field except `id`, `created_at` and `updated_at`. Fields hidden from or readonly for the current user, associations, `:file`, `:files` and `:rich_text` fields are never imported. |
| `import_upsert_key` | Fields that identify an existing record. A row whose values match a record (within the tenant scope) updates it; other rows create records. |
| `import_transform` | Block that receives the row's attributes (and, with two parameters, a context with `current_user` and `controller`) and returns the attributes to save |
| `import_validate` | Block that returns an error message, or an array of them, for an invalid row |
| `import_options max_rows:` | Largest number of rows a file may have (default 5,000) |
| `import_options preview_rows:` | Number of rows the preview shows (default 20) |

File headers are matched to fields by name or label, ignoring case, spaces and punctuation, so
`Email`, `email` and `E-mail` all map to `:email`. A CSV file needs a header row. A JSON file is
an array of objects, or an object with a `records` array.

## The Import Flow

1. **Upload.** `GET /admin/:resource_name/import` shows the upload form: the file, its format,
   and the list of importable fields. The form posts the file to
   `POST /admin/:resource_name/import/preview` as a full-page request (`data-turbo="false"`).
2. **Preview.** The preview page shows how the headers map to fields and the first
   `preview_rows` rows, with their values as they will be saved. Each row is validated like the
   real import: the `import_validate` block, and the model validations against the record an
   upsert would update, so a row that updates an existing record is not reported as "has
   already been taken". A file with more than `max_rows` rows is rejected here, with the alert
   "Import contains N rows, exceeding the M row limit".
3. **Import.** The "Import N rows" button posts the previewed file back to
   `POST /admin/:resource_name/import`, so the file is not uploaded twice, and imports every row
   of the file, not only the previewed ones. The browser returns to the index with a summary
   such as "Import finished: 12 created, 3 updated, 1 failed." Rows that fail validation are
   counted as failed and the other rows are saved.

Only a real file upload is accepted as the `file` parameter.

### Size Limit of the Import Step

The preview page carries the previewed file in a hidden form field, Base64-encoded, which
makes it about 33% larger than the file. The browser posts it as a multipart form field.
Rack 3.1 and later count non-file multipart fields against
`RACK_MULTIPART_BUFFERED_UPLOAD_BYTESIZE_LIMIT`, which is 16 MiB by default, so a larger file
could be previewed but never imported. The preview therefore rejects files larger than 12 MB
(12,000,000 bytes) with the alert "The file is larger than 12 MB. Split it into smaller
files." (`iron_admin.imports.errors.file_too_large`). Split larger files, or import them from
Ruby.

The 12 MB limit is fixed: raising the Rack variable does not raise it. If you lower the Rack
variable below 16 MiB, files that pass the preview can fail on the Import button again.

## Importing from Ruby

The importer runs without the UI, for example in a Rake task or a console:

```ruby
File.open("users.csv") do |file|
  result = IronAdmin::Import::Importer.new(IronAdmin::Resources::UserResource, file: file, format: :csv).execute!
  puts "#{result.created_count} created, #{result.updated_count} updated, #{result.failed_count} failed"
  result.errors.each { |error| puts "Row #{error.row_number}: #{error.message}" }
end
```

`Importer#preview` returns the same `IronAdmin::Import::ImportPreview` the preview page shows.
Pass `context:` (an object that responds to `current_user`) when field visibility, readonly
rules, or your `import_transform` and `import_validate` blocks need the user. Rows are numbered
from 2, as in a spreadsheet whose first row is the header, for CSV and JSON files alike.

## Overriding the Import Views

If you override the import views (`app/views/iron_admin/imports/`), keep what the flow relies
on:

- `new.html.haml`: the upload form must have `data: { turbo: false }`. Turbo Drive only accepts
  a redirect after a form submission, and the preview is rendered in reply to the POST.
- `preview.html.haml`: add a form that POSTs to `resource_import_path(@resource_class.resource_name)`
  with `multipart: true` and the hidden fields `import_format` (`@import_format`) and
  `import_data` (`@import_data`). Without it the page has no Import button.
- `@preview.cell_text(row, field_name)` returns the text of a preview cell: blank for missing
  values, dates and times in the default formats of the show page ("Oct 20, 2026",
  "Oct 20, 2026 at 10:00 AM"), whatever the locale, and JSON for hash and array values.

The texts come from the `iron_admin.imports` translation keys. `iron_admin.imports.preview.summary`
("%{count} rows detected.") and `iron_admin.imports.preview.import_button`
("Import %{count} rows") are pluralized with `one` and `other` forms.
