# frozen_string_literal: true

require "pagy"
require "view_component"
require "heroicon"
require "haml-rails"
require "turbo-rails"
require "stimulus-rails"

module IronAdmin
  # Rails Engine that provides the admin panel functionality.
  #
  # The Engine is mounted in your application's routes to expose
  # the admin panel at a path of your choice (typically /admin).
  #
  # @example Mounting the engine in config/routes.rb
  #   Rails.application.routes.draw do
  #     mount IronAdmin::Engine => "/admin"
  #   end
  #
  # @see file:docs/getting-started/installation.md Installation Guide
  class Engine < ::Rails::Engine
    isolate_namespace IronAdmin

    initializer "iron_admin.assets" do |app|
      if app.config.respond_to?(:assets) && app.config.assets
        app.config.assets.precompile += %w[iron_admin_manifest]
        app.config.assets.paths << root.join("vendor/assets/javascripts")
        app.config.assets.paths << root.join("app/javascript")
      end
    end

    initializer "iron_admin.importmap", before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/importmap.rb") if app.config.respond_to?(:importmap)
    end

    initializer "iron_admin.i18n" do
      config.i18n.load_path += Dir[root.join("config", "locales", "**", "*.yml")]
    end

    # Expose `heroicon` directly on every ViewComponent instance.
    # ViewComponent does not auto-include host-app `ApplicationHelper`
    # methods on component templates, so calling `heroicon "users"` from
    # a HAML template would otherwise raise `NoMethodError` (depending on
    # ViewComponent version). Including the helper module on
    # `ViewComponent::Base` makes `heroicon` available to every component
    # template and Ruby method without requiring `helpers.heroicon`.
    initializer "iron_admin.view_component_heroicon" do
      ActiveSupport.on_load(:view_component) do
        include Heroicon::ApplicationHelper
      end
    end

    initializer "iron_admin.autoload", before: :set_autoload_paths do
      resource_path = Rails.root.join("app/iron_admin")
      Rails.autoloaders.main.push_dir(resource_path, namespace: IronAdmin) if resource_path.exist?
    end

    config.to_prepare do
      resource_path = Rails.root.join("app/iron_admin")
      if resource_path.exist?
        IronAdmin::ResourceRegistry.reset!
        Rails.autoloaders.main.eager_load_dir(resource_path)
      end
    end
  end
end
