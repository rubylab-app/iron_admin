# frozen_string_literal: true

module IronAdmin
  # Rails generators for IronAdmin.
  module Generators
    # Generator for installing IronAdmin into a Rails application.
    #
    # This generator sets up the basic structure needed to use IronAdmin:
    # - Creates the app/iron_admin directory for resource definitions
    # - Adds an initializer with default configuration
    # - Creates a sample dashboard
    # - Mounts the engine at /admin in routes
    # - Adds the Tailwind CSS import for engine styles
    #
    # @example Running the generator
    #   rails generate iron_admin:install
    #
    # @see file:docs/getting-started/installation.md Installation Guide
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      # Creates the directory structure for resource and dashboard definitions.
      # @return [void]
      def create_iron_admin_directories
        empty_directory "app/iron_admin/resources"
        empty_directory "app/iron_admin/dashboards"
      end

      # Copies the initializer template with default configuration.
      # @return [void]
      def copy_initializer
        template "initializer.rb.tt", "config/initializers/iron_admin.rb"
      end

      # Copies the dashboard template.
      # @return [void]
      def copy_dashboard
        template "dashboard.rb.tt", "app/iron_admin/dashboards/admin_dashboard.rb"
      end

      # Adds the engine mount to config/routes.rb.
      # @return [void]
      def add_route
        route 'mount IronAdmin::Engine => "/admin"'
      end

      # Candidate Tailwind entry points, in priority order. Covers
      # tailwindcss-rails 4.x layout (`app/assets/tailwind/application.css`)
      # and the tailwindcss-rails 3.x / cssbundling-rails layout
      # (`app/assets/stylesheets/application.tailwind.css`).
      TAILWIND_CSS_CANDIDATES = %w[
        app/assets/tailwind/application.css
        app/assets/stylesheets/application.tailwind.css
      ].freeze

      # Adds the IronAdmin CSS import to the Tailwind application stylesheet.
      #
      # This import is required so the Tailwind compiler scans the engine's
      # views and components for CSS utility classes. Without it, the admin
      # panel renders unstyled.
      #
      # If no known Tailwind entry point is detected (e.g. the host added
      # `gem "iron_admin"` after `rails new --skip-bundle`, before the
      # tailwindcss installer ran), the generator emits a yellow `skip`
      # status line with the exact `@import` directive the user needs to
      # add manually — instead of returning silently and leaving the admin
      # panel unstyled with no breadcrumb to the cause.
      #
      # @return [void]
      def add_tailwind_import
        import_line = '@import "../builds/tailwind/iron_admin";'

        css_path = TAILWIND_CSS_CANDIDATES.find { |p| File.exist?(File.join(destination_root, p)) }

        unless css_path
          say_status :skip,
                     "no Tailwind entry point found; add #{import_line} to your Tailwind " \
                     "application file once it's created (typically " \
                     "#{TAILWIND_CSS_CANDIDATES.first})",
                     :yellow
          return
        end

        content = File.read(File.join(destination_root, css_path))
        return if content.include?(import_line)

        append_to_file css_path, "#{import_line}\n"
      end
    end
  end
end
