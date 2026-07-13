---
title: Home
layout: home
nav_order: 1
description: "IronAdmin — convention-over-configuration admin panel engine for Ruby on Rails."
permalink: /
---

# IronAdmin
{: .fs-9 }

Convention-over-configuration admin panel engine for Ruby on Rails. Build beautiful admin
interfaces with minimal code.
{: .fs-6 .fw-300 }

[Get started now](getting-started/){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View on GitHub](https://github.com/rubylab-app/iron_admin){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## What is IronAdmin?

IronAdmin is a mountable Rails Engine that auto-generates CRUD admin interfaces directly
from your ActiveRecord (or Mongoid) models. Mount it at `/admin`, point it at your models,
and get a polished, searchable, themeable admin panel with almost no boilerplate.

```ruby
# Gemfile
gem "iron_admin"
gem "tailwindcss-rails"
```

```bash
bundle install
rails generate iron_admin:install
```

## Features

- **Zero-configuration CRUD** — forms and tables inferred from your database schema.
- **Resource DSL** — customize fields, filters, scopes, and actions in clean Ruby.
- **Dashboard builder** — metrics, charts, and recent-record widgets.
- **Theme system** — every UI element is a configurable Tailwind class.
- **Authorization** — a built-in policy DSL for fine-grained access control.
- **Adapters** — pluggable data-layer support (ActiveRecord, Mongoid, and custom).
- **Search & export** — global search and CSV/JSON export out of the box.

## Requirements

- Ruby >= 3.2
- Rails >= 7.1
- [tailwindcss-rails](https://github.com/rails/tailwindcss-rails) >= 4.0

## Where to next?

| I want to… | Go to |
|------------|-------|
| Install IronAdmin | [Installation](getting-started/installation/) |
| Build my first admin panel | [Quick Start](getting-started/quick-start/) |
| Learn the resource DSL | [Resource DSL](guides/resource-dsl/) |
| Secure the admin | [Authorization](authorization/) |
| Support a custom data layer | [Adapters](adapters/) |
| Upgrade a major version | [Upgrade Guide](upgrade-guide/) |
