# frozen_string_literal: true

require "iron_admin/configuration/theme"
require "iron_admin/configuration/components"

module IronAdmin
  # Global configuration for the IronAdmin admin panel.
  #
  # Configure IronAdmin in an initializer using the {IronAdmin.configure} method.
  # All configuration options are optional and have sensible defaults.
  #
  # @example Basic configuration
  #   # config/initializers/iron_admin.rb
  #   IronAdmin.configure do |config|
  #     config.title = "My Admin"
  #     config.per_page = 50
  #
  #     config.authenticate do |controller|
  #       controller.redirect_to "/login" unless controller.current_user&.admin?
  #     end
  #
  #     config.current_user do |controller|
  #       controller.current_user
  #     end
  #   end
  #
  # @example Multi-tenant configuration
  #   IronAdmin.configure do |config|
  #     config.tenant_scope do |scope|
  #       scope.where(organization_id: Current.organization.id)
  #     end
  #   end
  #
  # @example Audit logging configuration
  #   IronAdmin.configure do |config|
  #     config.audit_enabled = true
  #     config.audit_storage = :database  # or :memory
  #   end
  #
  # @example Theme configuration
  #   IronAdmin.configure do |config|
  #     config.theme do |t|
  #       t.primary_color = "#4F46E5"
  #       t.sidebar_bg = "#1F2937"
  #     end
  #   end
  #
  # @see IronAdmin.configure
  # @see IronAdmin::Configuration::Theme
  class Configuration
    # @return [String] The admin panel title displayed in the header
    # @example
    #   config.title = "My Company Admin"
    attr_accessor :title

    # @return [String, nil] Path to a custom logo image
    attr_accessor :logo

    # @return [Integer] Number of records per page (default: 25)
    attr_accessor :per_page

    # @return [Symbol] Default sort column (default: :created_at)
    attr_accessor :default_sort

    # @return [Symbol] Default sort direction, :asc or :desc (default: :desc)
    attr_accessor :default_sort_direction

    # @return [Symbol] Search engine to use (default: :default)
    attr_accessor :search_engine

    # @return [Hash{String => String}] Mapping of status values to badge colors
    # @see DEFAULT_BADGE_COLORS
    attr_accessor :badge_colors

    # @return [Boolean] Whether audit logging is enabled (default: false)
    attr_accessor :audit_enabled

    # @return [Symbol] Audit storage backend, :memory or :database (default: :memory)
    attr_accessor :audit_storage

    # @return [Boolean] Whether the actions column stays fixed on horizontal scroll (default: true)
    attr_accessor :sticky_actions_column

    # @return [String, nil] Base URL for HTTP adapter (e.g., "https://api.example.com/v1")
    attr_accessor :http_base_url

    # @return [Hash] Default headers for HTTP adapter (e.g., auth tokens)
    attr_accessor :http_headers

    # @return [Proc, nil] Authentication block
    # @see #authenticate
    attr_reader :authenticate_block

    # @return [Proc, nil] Current user block
    # @see #current_user
    attr_reader :current_user_block

    # @return [Proc, nil] Action callback block
    # @see #on_action
    attr_reader :on_action_block

    # @return [IronAdmin::Configuration::Theme] Theme configuration
    # @see #theme
    attr_reader :theme_config

    # @return [IronAdmin::Configuration::Components] Component overrides
    attr_reader :components

    # @return [Proc, nil] Tenant scope block
    # @see #tenant_scope
    attr_reader :tenant_scope_block

    # Maps color names to Tailwind CSS classes for badges.
    # @return [Hash{Symbol => String}]
    BADGE_COLOR_CLASSES = {
      green: "bg-green-100 text-green-800",
      red: "bg-red-100 text-red-800",
      yellow: "bg-yellow-100 text-yellow-800",
      blue: "bg-blue-100 text-blue-800",
      indigo: "bg-indigo-100 text-indigo-800",
      purple: "bg-purple-100 text-purple-800",
      pink: "bg-pink-100 text-pink-800",
      orange: "bg-orange-100 text-orange-800",
      teal: "bg-teal-100 text-teal-800",
      gray: "bg-gray-100 text-gray-800",
    }.freeze

    # Default mappings from common status values to badge colors.
    # These are applied automatically to enum and status fields.
    # @return [Hash{String, Boolean => String}]
    DEFAULT_BADGE_COLORS = {
      # Common status values
      "active" => "green",
      "inactive" => "gray",
      "enabled" => "green",
      "disabled" => "gray",
      "pending" => "yellow",
      "processing" => "blue",
      "in_progress" => "blue",
      "completed" => "green",
      "done" => "green",
      "success" => "green",
      "failed" => "red",
      "error" => "red",
      "cancelled" => "red",
      "canceled" => "red",
      "rejected" => "red",
      "declined" => "red",
      "approved" => "green",
      "accepted" => "green",
      "published" => "green",
      "unpublished" => "gray",
      "draft" => "gray",
      "archived" => "gray",
      "expired" => "red",
      "suspended" => "red",
      "blocked" => "red",
      # Boolean representations
      true => "green",
      false => "red",
      "true" => "green",
      "false" => "red",
      "yes" => "green",
      "no" => "red",
    }.freeze

    # Creates a new Configuration with default values.
    def initialize
      @title = "Admin"
      @per_page = 25
      @default_sort = :created_at
      @default_sort_direction = :desc
      @search_engine = :default
      @badge_colors = DEFAULT_BADGE_COLORS.dup
      @theme_config = Theme.new
      @components = Components.new
      @audit_enabled = false
      @audit_storage = :memory
      @sticky_actions_column = true
      @http_base_url = nil
      @http_headers = {}
    end

    # Defines the authentication check for admin access.
    #
    # The block receives the controller instance and should redirect
    # unauthenticated users or return false to deny access.
    #
    # @yield [controller] Block executed before each admin request
    # @yieldparam controller [ActionController::Base] The current controller
    #
    # @example Redirect unauthenticated users
    #   config.authenticate do |controller|
    #     controller.redirect_to "/login" unless controller.session[:user_id]
    #   end
    #
    # @example Require admin role
    #   config.authenticate do |controller|
    #     unless controller.current_user&.admin?
    #       controller.head :forbidden
    #     end
    #   end
    #
    # @return [void]
    def authenticate(&block)
      @authenticate_block = block
    end

    # Defines how to retrieve the current user.
    #
    # The block receives the controller and should return the current user object.
    # This user is passed to policy conditions and field visibility procs.
    #
    # @yield [controller] Block that returns the current user
    # @yieldparam controller [ActionController::Base] The current controller
    # @yieldreturn [Object] The current user object
    #
    # @example
    #   config.current_user do |controller|
    #     controller.current_user
    #   end
    #
    # @example Using session
    #   config.current_user do |controller|
    #     User.find_by(id: controller.session[:user_id])
    #   end
    #
    # @return [void]
    def current_user(&block)
      @current_user_block = block
    end

    # Defines a callback executed after any CRUD action.
    #
    # Use this for audit logging, notifications, or other side effects.
    #
    # @yield [action, resource, record, user] Block executed after actions
    # @yieldparam action [Symbol] The action (:create, :update, :delete)
    # @yieldparam resource [Class] The resource class
    # @yieldparam record [ActiveRecord::Base] The affected record
    # @yieldparam user [Object] The current user
    #
    # @example Audit logging
    #   config.on_action do |action, resource, record, user|
    #     AuditLog.create!(
    #       action: action,
    #       resource: resource.name,
    #       record_id: record.id,
    #       user_id: user.id
    #     )
    #   end
    #
    # @return [void]
    def on_action(&block)
      @on_action_block = block
    end

    # Configures the admin panel theme.
    #
    # @yield [theme] Block to configure theme options
    # @yieldparam theme [IronAdmin::Configuration::Theme] The theme config
    # @return [IronAdmin::Configuration::Theme] The theme configuration
    #
    # @example
    #   config.theme do |t|
    #     t.primary_color = "#4F46E5"
    #     t.sidebar_bg = "#1F2937"
    #     t.font_family = "Inter, sans-serif"
    #   end
    #
    # @see IronAdmin::Configuration::Theme
    def theme
      yield @theme_config if block_given?
      @theme_config
    end

    # Defines a tenant scope for multi-tenant applications.
    #
    # The block receives an ActiveRecord::Relation and should return
    # a scoped relation that only includes records for the current tenant.
    # This scope is applied to all resource queries.
    #
    # @yield [scope] Block that scopes queries to current tenant
    # @yieldparam scope [ActiveRecord::Relation] The base query scope
    # @yieldreturn [ActiveRecord::Relation] The tenant-scoped query
    #
    # @example Organization-based tenancy
    #   config.tenant_scope do |scope|
    #     scope.where(organization_id: Current.organization.id)
    #   end
    #
    # @example Account-based tenancy
    #   config.tenant_scope do |scope|
    #     scope.where(account_id: Current.account.id)
    #   end
    #
    # @note Ensure the tenant context (e.g., Current.organization) is set
    #   before IronAdmin requests are processed, typically via a before_action.
    #
    # @return [void]
    def tenant_scope(&block)
      @tenant_scope_block = block
    end
  end
end
