# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

IronAdmin is a Rails Engine gem that provides a convention-over-configuration admin panel. It auto-generates CRUD interfaces from ActiveRecord models with minimal setup.

## Development Commands

```bash
# Install dependencies
bundle install

# Run all tests
bundle exec rspec

# Run a single test file
bundle exec rspec spec/lib/iron_admin/resource_spec.rb

# Run a specific test by line number
bundle exec rspec spec/lib/iron_admin/resource_spec.rb:42

# Run tests with coverage report (outputs to coverage/)
bundle exec rspec  # SimpleCov runs automatically

# Run Rubocop linter
bundle exec rubocop

# Auto-fix Rubocop offenses
bundle exec rubocop -A

# Check Ruby version (should match .ruby-version)
ruby -v
```

## Architecture

### Rails Engine Structure

This is a mountable Rails Engine (`isolate_namespace IronAdmin`). Host apps mount it at a path like `/admin`:

```ruby
# Host app's config/routes.rb
mount IronAdmin::Engine, at: "/admin"
```

### Core Domain Classes (lib/iron_admin/)

- **Resource** - Base class for admin resources. Subclasses define field overrides, filters, scopes, actions, and menu options. Auto-registers with ResourceRegistry on inheritance.
- **ResourceRegistry** - Singleton registry of all Resource subclasses. Resources self-register via `inherited` hook.
- **FieldInferrer** - Introspects ActiveRecord models to generate Field objects from database columns.
- **Field** - Value object representing a displayable/editable field with type, visibility, and readonly options.
- **Dashboard** - Base class for dashboard definitions with metrics, charts, and recent record listings.
- **Policy** - DSL for per-resource authorization rules (allow/deny actions with conditions).
- **Configuration** - Global settings (title, auth, theme, pagination). Access via `IronAdmin.configuration`.

### Resource Auto-Discovery

Resources are placed in `app/iron_admin/resources/` in the host app, and dashboards in `app/iron_admin/dashboards/`. The engine uses `push_dir` with `namespace: IronAdmin` so Zeitwerk maps these to `IronAdmin::Resources::*` and `IronAdmin::Dashboards::*` respectively. The directory is eager-loaded after Rails initialization (see `engine.rb`), triggering the `inherited` callback that auto-registers resources.

### Controllers (app/controllers/iron_admin/)

- **ResourcesController** - Handles all CRUD operations for any registered resource. Uses dynamic routing (`:resource_name` param) to look up the correct Resource class.
- **DashboardController** - Renders the configured Dashboard class.
- **SearchController** - Global search across all searchable resources.
- **ExportsController** - CSV/JSON export for resources.

### ViewComponents (app/components/iron_admin/)

Uses ViewComponent gem. Components are in `layout/` (shell, sidebar, navbar) and `dashboard/` (metric cards, recent tables).

### Configuration Classes (lib/iron_admin/configuration/)

- **Theme** - Tailwind CSS class customization for every UI element.
- **Components** - Override default ViewComponent classes with custom implementations.

### Authorization System

- **Policy** - Per-resource authorization with `allow`/`deny` DSL for CRUD and custom actions.
- Controllers check `@resource_class._policy_block` and call `Policy#allowed?`.
- Field-level visibility/readonly via `field.visible?(user)` and `field.readonly?(user)`.

### Audit Logging

- Enable with `config.audit_enabled = true`.
- `AuditLog.log(event)` stores entries with user, action, resource, record_id, changes, ip_address, timestamp.
- View audit log at `/admin/audit`.

### Multi-Tenant Support

- Configure with `config.tenant_scope { |scope| scope.where(org_id: Current.org.id) }`.
- Applied automatically to all resource queries via `base_scope`.

### Soft Delete Support

- Auto-detects `deleted_at` column on models.
- Auto-registers `with_deleted`, `only_deleted` scopes and `restore` action.

## Testing

Tests use a dummy Rails app at `spec/dummy/`. The dummy app has test models (User, License) and corresponding resources.

**All tests must follow [BetterSpecs](https://www.betterspecs.org/) guidelines:**
- Use `describe` for methods, `context` for conditions
- Use `subject` and `let` for setup
- One expectation per test when possible
- Use meaningful test descriptions

```ruby
# spec/rails_helper.rb loads the dummy app
require_relative "dummy/config/environment"
```

Each test resets configuration and registry:
```ruby
config.before(:each) do
  IronAdmin.reset_configuration!
  IronAdmin::ResourceRegistry.reset!
end
```

## Key Patterns

### Resource DSL

Resources use class-level DSL methods that modify `class_attribute` values:
```ruby
module IronAdmin
  module Resources
    class UserResource < IronAdmin::Resource
      field :status, type: :badge        # field_overrides
      searchable :name, :email           # _searchable_columns
      filter :role, type: :select        # defined_filters
      scope :active, -> { where(active: true) }  # defined_scopes
      index_fields :id, :name, :email    # index_field_names
      menu priority: 1, group: "Users"   # menu_options
    end
  end
end
```

### Model Inference

Resource class name maps to model: `IronAdmin::Resources::UserResource` → `User` model (strips "IronAdmin::Resources::" prefix and "Resource" suffix, then constantizes).

### Theme Customization

All UI classes are configurable via `IronAdmin.configure { |c| c.theme { |t| ... } }`. Theme properties return Tailwind CSS classes.

## Important Guidelines

### Rubocop Configuration

**NEVER modify `.rubocop.yml` unless absolutely necessary.** Always refactor the code to comply with Rubocop rules instead of adding exceptions. Adding exceptions leads to bad practices accumulating over time. Only modify `.rubocop.yml` as a last resort when there is genuinely no other way to fix the issue.

### Copilot Code Review

After creating a pull request, **wait 10 minutes** and then check if GitHub Copilot has left review comments. Copilot reviews every PR automatically via the repository ruleset.

- **If comments are valid:** apply the fixes, commit, and push to the PR branch.
- **If comments are invalid:** dismiss them with a brief justification explaining why.

Do NOT merge a PR without first checking for Copilot feedback.

### Git Workflow

**NEVER push directly to main.** All changes must go through a feature branch and pull request — no exceptions, not even for documentation or configuration files.
