---
title: Installation
parent: Getting Started
nav_order: 1
permalink: /getting-started/installation/
---

# Installation
{: .no_toc }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Requirements

- Ruby >= 3.2
- Rails >= 7.1
- [tailwindcss-rails](https://github.com/rails/tailwindcss-rails) >= 4.0

## Step 1: Add the Gems

Add IronAdmin and `tailwindcss-rails` to your `Gemfile`:

```ruby
gem "iron_admin"
gem "tailwindcss-rails"
```

Then run:

```bash
bundle install
```

## Step 2: Run the Install Generator

```bash
rails generate iron_admin:install
```

This creates:

| File | Purpose |
|------|---------|
| `config/initializers/iron_admin.rb` | Main configuration (title, auth, theme) |
| `app/iron_admin/resources/` | Directory for resource definitions |
| `app/iron_admin/dashboards/` | Directory for dashboard definitions |
| `app/iron_admin/dashboards/admin_dashboard.rb` | Default dashboard class |

It also:
- Mounts the engine at `/admin` in `config/routes.rb`
- Adds the IronAdmin CSS import to `app/assets/tailwind/application.css`

## Step 3: Mount the Engine (if not auto-mounted)

In `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  mount IronAdmin::Engine => "/admin"
end
```

## Step 4: Configure Authentication

Edit `config/initializers/iron_admin.rb`:

```ruby
IronAdmin.configure do |config|
  config.title = "My App Admin"

  config.authenticate do |controller|
    unless controller.session[:user_id]
      controller.redirect_to "/login"
    end
  end

  config.current_user do |controller|
    User.find_by(id: controller.session[:user_id])
  end
end
```

## Step 5: Create Your First Resource

```bash
rails generate iron_admin:resource User
```

This creates `app/iron_admin/resources/user_resource.rb`. IronAdmin automatically infers
fields from your model's database schema.

## Step 6: Build CSS and Start the Server

```bash
rails tailwindcss:build
bin/rails server
```

Visit `/admin` and your admin panel is ready.

For development with live CSS recompilation, use `bin/dev` (which runs
`tailwindcss:watch` alongside the Rails server via foreman).

{: .note }
> There is a [known issue](https://github.com/rails/tailwindcss-rails/issues/602) in
> `tailwindcss-rails` v4 where `bin/dev` exits immediately after starting. If this happens,
> edit `Procfile.dev` and change the CSS line to
> `css: bin/rails tailwindcss:watch[always]`.

## Tailwind CSS Setup

IronAdmin uses Tailwind CSS v4 for all styling via the `tailwindcss-rails` gem.
Understanding how the CSS pipeline works will help you troubleshoot any styling issues.

### How it works

1. IronAdmin ships with `@source` directives at `app/assets/tailwind/iron_admin/engine.css`
   inside the gem. These tell the Tailwind compiler where to scan for CSS utility classes
   used by the engine's views, components, and helpers.

2. When `tailwindcss:build` runs, it first executes `tailwindcss:engines`. This task
   detects IronAdmin's engine CSS and creates a bridge file at
   `app/assets/builds/tailwind/iron_admin.css` containing an `@import` that points
   to the engine's CSS.

3. Your `app/assets/tailwind/application.css` must import this bridge file:

   ```css
   @import "tailwindcss";
   @import "../builds/tailwind/iron_admin";
   ```

4. The Tailwind compiler processes `application.css`, follows the imports, scans all
   the engine's source files via the `@source` directives, and generates the final
   `app/assets/builds/tailwind.css` with all necessary utility classes.

5. The engine's layout references `stylesheet_link_tag "tailwind"`, which serves
   this compiled CSS file.

### Manual setup (without the generator)

If you didn't use the install generator, or the import line is missing:

1. Verify `tailwindcss-rails` is in your Gemfile and installed
2. Add the import to `app/assets/tailwind/application.css`:

   ```css
   @import "tailwindcss";
   @import "../builds/tailwind/iron_admin";
   ```

3. Build the CSS:

   ```bash
   rails tailwindcss:build
   ```

4. Verify the build output:

   ```bash
   ls -la app/assets/builds/tailwind.css
   # Should be ~30KB+ (not ~6KB which indicates no utility classes)
   ```

### Troubleshooting

**Styles not loading (unstyled admin panel)**

This almost always means the Tailwind compiler didn't scan IronAdmin's source files.
Check:

1. The `@import "../builds/tailwind/iron_admin"` line exists in
   `app/assets/tailwind/application.css`
2. The bridge file exists at `app/assets/builds/tailwind/iron_admin.css`
   (run `rails tailwindcss:build` to regenerate it)
3. The compiled CSS at `app/assets/builds/tailwind.css` is large enough
   (~30KB+, not ~6KB)

**Bridge file not generated**

If `app/assets/builds/tailwind/iron_admin.css` doesn't exist after running
`rails tailwindcss:build`:

- Ensure `tailwindcss-rails` >= 4.0 is installed (`bundle info tailwindcss-rails`)
- Ensure `iron_admin` is properly loaded (check `bundle info iron_admin`)
- Try running `rails tailwindcss:engines` directly

**Styles disappear after bundle update**

The bridge file uses an absolute path to the gem's CSS. After updating the gem
(which changes the gem path), run `rails tailwindcss:build` to regenerate it.

## Dependencies

IronAdmin depends on the following gems (installed automatically):

| Gem | Version | Purpose |
|-----|---------|---------|
| `rails` | >= 7.1 | Framework |
| `view_component` | >= 3.0 | UI components |
| `turbo-rails` | >= 2.0 | Hotwire Turbo |
| `stimulus-rails` | >= 1.3 | Hotwire Stimulus |
| `pagy` | >= 6.0 | Pagination |
| `haml-rails` | >= 2.0 | Template engine |
| `heroicon` | >= 1.0 | SVG icons |

**Peer dependency** (must be added to your Gemfile manually):

| Gem | Version | Purpose |
|-----|---------|---------|
| `tailwindcss-rails` | >= 4.0 | Tailwind CSS compilation |
