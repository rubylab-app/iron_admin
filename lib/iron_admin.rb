# frozen_string_literal: true

require "iron_admin/version"
require "iron_admin/errors"
require "iron_admin/configuration"
require "iron_admin/adapters/base"
require "iron_admin/adapters/registry"
require "iron_admin/adapters/active_record"
require "iron_admin/adapters/http/model_proxy"
require "iron_admin/field"
require "iron_admin/field_type_config"
require "iron_admin/field_type_registry"
require "iron_admin/field_inferrer"
require "iron_admin/action_field"
require "iron_admin/nested_association"
require "iron_admin/nested_attributes_validator"
require "iron_admin/concerns/nestable"
require "iron_admin/concerns/soft_deletable"
require "iron_admin/concerns/importable"
require "iron_admin/filters/base_query_builder"
require "iron_admin/filters/active_record_query_builder"
require "iron_admin/filters/query_builder"
require "iron_admin/resource"
require "iron_admin/resource_registry"
require "iron_admin/tool"
require "iron_admin/tool_context"
require "iron_admin/tool_action"
require "iron_admin/tool_registry"
require "iron_admin/policy"
require "iron_admin/dashboard"
require "iron_admin/import/parser/csv"
require "iron_admin/import/parser/json"
require "iron_admin/import/column_mapper"
require "iron_admin/import/type_caster"
require "iron_admin/import/import_preview"
require "iron_admin/import/import_result"
require "iron_admin/import/importer"
require "iron_admin/audit_log"
require "iron_admin/engine"

# IronAdmin is a convention-over-configuration admin panel engine for Ruby on Rails.
#
# It automatically generates admin interfaces from your database schema with minimal
# configuration, following Rails conventions.
#
# == Getting Started
#
# 1. Add the gem to your Gemfile and run bundle install
# 2. Run the install generator: `rails generate iron_admin:install`
# 3. Mount the engine in config/routes.rb: `mount IronAdmin::Engine => "/admin"`
# 4. Create resources in app/iron_admin/resources/ for each model you want to manage
#
# == Key Concepts
#
# === Resources
# Resources define how models appear in the admin panel. Each resource is a class
# that inherits from {IronAdmin::Resource} and provides a DSL for configuring
# fields, filters, actions, and authorization.
#
#   module IronAdmin
#     module Resources
#       class UserResource < IronAdmin::Resource
#         field :email, readonly: true
#         field :password_digest, visible: false
#         searchable :name, :email
#         filter :role, type: :select, options: %w[admin user]
#       end
#     end
#   end
#
# === Dashboard
# The dashboard is the admin panel home page. Create a class inheriting from
# {IronAdmin::Dashboard} to define metrics, charts, and recent record lists.
#
#   module IronAdmin
#     module Dashboards
#       class AdminDashboard < IronAdmin::Dashboard
#         metric :total_users do
#           User.count
#         end
#         recent :orders, limit: 10
#       end
#     end
#   end
#
# === Configuration
# Global settings are configured in an initializer using {.configure}.
#
#   IronAdmin.configure do |config|
#     config.title = "My Admin"
#     config.authenticate { |c| c.redirect_to "/login" unless c.current_user }
#   end
#
# @see IronAdmin::Resource
# @see IronAdmin::Dashboard
# @see IronAdmin::Configuration
module IronAdmin
  class << self
    # @return [Class, nil] The dashboard class for the application
    attr_accessor :dashboard_class

    # Returns the global configuration instance.
    #
    # @return [IronAdmin::Configuration] The configuration object
    #
    # @example Access configuration
    #   IronAdmin.configuration.per_page  #=> 25
    def configuration
      @configuration ||= Configuration.new
    end

    # Configures IronAdmin using a block.
    #
    # This is the primary way to configure the admin panel. Call this method
    # in an initializer (config/initializers/iron_admin.rb).
    #
    # @yield [config] Block that configures IronAdmin
    # @yieldparam config [IronAdmin::Configuration] The configuration object
    #
    # @example Basic configuration
    #   IronAdmin.configure do |config|
    #     config.title = "My Admin Panel"
    #     config.per_page = 50
    #
    #     config.authenticate do |controller|
    #       controller.redirect_to "/login" unless controller.session[:user_id]
    #     end
    #
    #     config.current_user do |controller|
    #       User.find_by(id: controller.session[:user_id])
    #     end
    #   end
    #
    # @return [void]
    def configure
      yield configuration
    end

    # Resets all configuration to defaults.
    #
    # Primarily used in tests to ensure a clean state between examples.
    #
    # @api private
    # @return [void]
    def reset_configuration!
      @configuration = Configuration.new
      @dashboard_class = nil
    end

    def register_field_type(type_name, &)
      FieldTypeRegistry.register(type_name, &)
    end
  end
end
