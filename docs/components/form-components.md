# Form Components

Input components for building forms.

## TextInputComponent

Standard text input field.

```ruby
IronAdmin::Form::TextInputComponent.new(
  name: :email,              # Required: field name
  value: nil,                # Optional: current value
  type: :text,               # Optional: :text, :email, :password, :tel, :url
  placeholder: nil,          # Optional: placeholder text (auto-generated from name)
  disabled: false,           # Optional: disable input
  readonly: false,           # Optional: read-only input
  has_error: false           # Optional: show error styling
)
```

**Example:**

```haml
= render IronAdmin::Form::TextInputComponent.new(name: :email,
  value: @user.email,
  type: :email,
  placeholder: "user@example.com")
```

---

## SelectComponent

Dropdown select field.

```ruby
IronAdmin::Form::SelectComponent.new(
  name: :role,               # Required: field name
  options: options,          # Required: array of [label, value] pairs
  selected: nil,             # Optional: currently selected value
  include_blank: nil,        # Optional: blank option text
  disabled: false,           # Optional: disable select
  has_error: false           # Optional: show error styling
)
```

**Example:**

```haml
= render IronAdmin::Form::SelectComponent.new(name: :role,
  options: [["Admin", "admin"], ["User", "user"], ["Guest", "guest"]],
  selected: @user.role,
  include_blank: "Select a role...")
```

---

## CheckboxComponent

Boolean checkbox input.

```ruby
IronAdmin::Form::CheckboxComponent.new(
  name: :active,             # Required: field name
  label: "Active",           # Optional: checkbox label
  checked: false,            # Optional: checked state
  disabled: false,           # Optional: disable checkbox
  has_error: false           # Optional: show error styling
)
```

**Example:**

```haml
= render IronAdmin::Form::CheckboxComponent.new(name: :email_notifications,
  label: "Receive email notifications",
  checked: @user.email_notifications)
```

---

## TextareaComponent

Multi-line text input.

```ruby
IronAdmin::Form::TextareaComponent.new(
  name: :bio,                # Required: field name
  value: nil,                # Optional: current value
  rows: 4,                   # Optional: visible rows
  placeholder: nil,          # Optional: placeholder text
  disabled: false,           # Optional: disable textarea
  readonly: false,           # Optional: read-only textarea
  has_error: false           # Optional: show error styling
)
```

**Example:**

```haml
= render IronAdmin::Form::TextareaComponent.new(name: :description,
  value: @product.description,
  rows: 6,
  placeholder: "Enter product description...")
```

---

## DatePickerComponent

Date and datetime input.

```ruby
IronAdmin::Form::DatePickerComponent.new(
  name: :published_at,       # Required: field name
  value: nil,                # Optional: current value (Date/DateTime/String)
  type: :datetime_local,     # Optional: :date, :datetime, :datetime_local, :time
  min: nil,                  # Optional: minimum date
  max: nil,                  # Optional: maximum date
  disabled: false,           # Optional: disable input
  has_error: false           # Optional: show error styling
)
```

**Example:**

```haml
= render IronAdmin::Form::DatePickerComponent.new(name: :start_date,
  value: @event.start_date,
  type: :datetime_local,
  min: Date.today)
```

---

## BelongsToComponent

Association select for belongs_to relationships.

```ruby
IronAdmin::Form::BelongsToComponent.new(
  name: :user_id,                  # Required: foreign key field name
  association_class: User,         # Required: associated model class
  selected: nil,                   # Optional: currently selected ID
  display_method: :name,           # Optional: method for display text
  include_blank: true,             # Optional: include blank option
  disabled: false,                 # Optional: disable select
  has_error: false                 # Optional: show error styling
)
```

**Example:**

```haml
= render IronAdmin::Form::BelongsToComponent.new(name: :category_id,
  association_class: Category,
  selected: @product.category_id,
  display_method: :title)
```

---

## FieldWrapperComponent

Wrapper with label, hint, and error display.

```ruby
IronAdmin::Form::FieldWrapperComponent.new(
  name: :email,              # Required: field name
  label: nil,                # Optional: label text (auto-generated from name)
  errors: [],                # Optional: array of error messages
  required: false,           # Optional: show required indicator
  hint: nil,                 # Optional: hint text below input
  span_full: false           # Optional: span full width in grid
)
```

**Example:**

```haml
= render IronAdmin::Form::FieldWrapperComponent.new(name: :email,
  label: "Email Address",
  errors: @user.errors[:email],
  required: true,
  hint: "We'll never share your email.") do
  = render IronAdmin::Form::TextInputComponent.new(name: :email,
    value: @user.email,
    has_error: @user.errors[:email].any?)
```
