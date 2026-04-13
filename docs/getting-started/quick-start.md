# Quick Start

Get a full admin panel running in 5 steps.

## Prerequisites

IronAdmin uses [Tailwind CSS](https://tailwindcss.com/) for all styling. Ensure your application has `tailwindcss-rails` installed:

```bash
bundle add tailwindcss-rails
rails tailwindcss:install
```

## 1. Install

```bash
bundle add iron_admin
rails generate iron_admin:install
```

## 2. Configure Authentication

```ruby
# config/initializers/iron_admin.rb
IronAdmin.configure do |config|
  config.title = "My App Admin"

  config.authenticate do |controller|
    user = User.find_by(id: controller.session[:user_id])
    controller.redirect_to "/login" unless user&.admin?
  end

  config.current_user do |controller|
    User.find_by(id: controller.session[:user_id])
  end
end
```

## 3. Generate Resources

```bash
rails generate iron_admin:resource User
rails generate iron_admin:resource Product
rails generate iron_admin:resource Order
```

IronAdmin infers all fields from your database schema automatically. No configuration needed for basic CRUD.

## 4. Customize a Resource

```ruby
# app/iron_admin/resources/user_resource.rb
class UserResource < IronAdmin::Resource
  field :role, type: :badge, colors: { admin: :purple, user: :blue }
  field :email, type: :text

  searchable :name, :email
  filter :role, type: :select, choices: User.roles.keys
  filter :created_at, type: :date_range

  scope :admins, -> { where(role: :admin) }
  scope :recent, -> { where("created_at > ?", 7.days.ago) }

  index_fields :id, :name, :email, :role, :created_at
  form_fields :name, :email, :role

  menu priority: 1, icon: "users", group: "People"

  action :lock, icon: "lock-closed", confirm: true do |record|
    record.update!(locked_at: Time.current)
  end
end
```

## 5. Create a Dashboard

```ruby
# app/iron_admin/dashboards/admin_dashboard.rb
class AdminDashboard < IronAdmin::Dashboard
  metric :total_users, format: :number do
    User.count
  end

  metric :monthly_revenue, format: :currency do
    Payment.where("created_at > ?", 30.days.ago).sum(:amount)
  end

  recent :users, limit: 5, scope: -> { order(created_at: :desc) }
  recent :payments, limit: 5
end
```

Build CSS and start the server:

```bash
rails tailwindcss:build
bin/rails server
```

Visit `/admin` and your admin panel is ready.
