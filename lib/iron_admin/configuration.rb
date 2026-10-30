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
  #       user = User.find_by(id: controller.session[:user_id])
  #       controller.redirect_to "/login" unless user&.admin?
  #     end
  #
  #     config.current_user do |controller|
  #       User.find_by(id: controller.session[:user_id])
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
  #     config.audit_user_labels do |identifiers|
  #       User.where(id: identifiers).pluck(:id, :email).to_h
  #     end
  #   end
  #
  # @example Theme configuration
  #   IronAdmin.configure do |config|
  #     config.theme do |t|
  #       t.font_stylesheet_url = nil
  #       t.label_transform = "uppercase tracking-wider"
  #     end
  #     config.register_theme(:midnight, label: "Midnight") { |t| t.color_scheme = "dark" }
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

    # @return [String, nil] Icon the admin layout links with +<link rel="icon">+: a path, a URL or
    #   an asset name, resolved like {#logo} (default: nil, no icon link, so browsers request /favicon.ico)
    # @example
    #   config.favicon = "/icon.svg"
    attr_accessor :favicon

    # @return [Integer] Number of records per page (default: 25)
    attr_accessor :per_page

    # @return [Symbol] Default sort column (default: :created_at)
    attr_accessor :default_sort

    # @return [Symbol] Default sort direction, :asc or :desc (default: :desc)
    attr_accessor :default_sort_direction

    # Unused. The value is stored and returned, and nothing in IronAdmin reads it (default: :default).
    # @return [Symbol]
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

    # @return [Symbol] Live update strategy (:disabled or :polling)
    attr_accessor :live_updates

    # @return [ActiveSupport::Duration] Client polling interval for live updates
    attr_accessor :live_poll_interval

    # @return [ActiveSupport::Duration] Minimum interval between live broadcasts
    attr_accessor :live_throttle

    # When +true+, tools dispatch only actions declared with +tool_action+.
    # The legacy fallback that runs a tool's own public methods is off, and
    # undeclared names return 404. Declared actions are unchanged.
    #
    # @return [Boolean] whether undeclared tool actions are rejected (default: false)
    # @see IronAdmin::Tool
    attr_accessor :strict_tool_actions

    # @return [Proc, nil] Authentication block
    # @see #authenticate
    attr_reader :authenticate_block

    # @return [Proc, nil] Current user block
    # @see #current_user
    attr_reader :current_user_block

    # @return [Proc, nil] Action callback block
    # @see #on_action
    attr_reader :on_action_block

    # @return [Proc, nil] Block that labels the users of the audit log page
    # @see #audit_user_labels
    attr_reader :audit_user_labels_block

    # @return [Symbol] Name of the theme used when the request resolves no registered theme
    #   (default: :neutral)
    # @see #theme_resolver
    attr_reader :default_theme

    # @return [IronAdmin::Configuration::Components] Component overrides
    attr_reader :components

    # @return [Proc, nil] Tenant scope block
    # @see #tenant_scope
    attr_reader :tenant_scope_block

    # Name of the built-in theme, registered by every Configuration.
    # @return [Symbol]
    NEUTRAL_THEME = :neutral

    # Cookie that stores the theme picked in the theme switcher.
    # @return [String]
    THEME_COOKIE = "iron_admin_theme"

    # Resolver used until {#theme_resolver} is given a block: the theme cookie.
    # @return [Proc]
    DEFAULT_THEME_RESOLVER = ->(request) { request.cookies[THEME_COOKIE] }

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
      @favicon = nil
      @per_page = 25
      @default_sort = :created_at
      @default_sort_direction = :desc
      @search_engine = :default
      @badge_colors = DEFAULT_BADGE_COLORS.dup
      @themes = { NEUTRAL_THEME => Theme.new(name: NEUTRAL_THEME) }
      # Name => owner. +:app+ is the application (Neutral and {#register_theme}); a String is a
      # plugin's +plugin_name+, a logical identity, not proof that two implementations match.
      @theme_owners = { NEUTRAL_THEME => :app }
      @default_theme = NEUTRAL_THEME
      @theme_resolver = DEFAULT_THEME_RESOLVER
      @components = Components.new
      @audit_enabled = false
      @audit_storage = :memory
      @sticky_actions_column = true
      @http_base_url = nil
      @http_headers = {}
      @live_updates = :disabled
      @live_poll_interval = 3.seconds
      @live_throttle = 0.5.seconds
      @strict_tool_actions = false
    end

    # Defines the authentication check for admin access.
    #
    # The block receives the controller and runs before each admin request.
    # Redirect or render inside the block to customize the response. Make
    # +false+ the block's last value to deny access with 403: HTML gets the
    # error page without the admin shell, and other formats a bare 403.
    # +nil+ or any other value allows the request. A block that has already
    # redirected or rendered keeps that response, whatever its value is.
    # Stop early with +next false+. Do not use +return+ inside the block:
    # from an initializer it raises +LocalJumpError+.
    #
    # The controller inherits from ActionController::Base, not from the host
    # application's ApplicationController, so helpers defined only there are
    # missing. Read cookies with +controller.request.cookie_jar+;
    # +controller.cookies+ is private.
    #
    # @yield [controller] Block executed before each admin request
    # @yieldparam controller [ActionController::Base] The current controller
    # @yieldreturn [false, nil, Object] +false+ denies with 403; anything else allows the request
    #
    # @example Redirect unauthenticated users
    #   config.authenticate do |controller|
    #     controller.redirect_to "/login" unless controller.session[:user_id]
    #   end
    #
    # @example Deny with 403 unless the user is an admin
    #   config.authenticate do |controller|
    #     # || false: a missing user makes &.admin? nil, and nil allows the request.
    #     User.find_by(id: controller.session[:user_id])&.admin? || false
    #   end
    #
    # @example Choose the response yourself
    #   config.authenticate do |controller|
    #     user = User.find_by(id: controller.session[:user_id])
    #     controller.head :forbidden unless user&.admin?
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
    #     User.find_by(id: controller.session[:user_id])
    #   end
    #
    # @example With Devise
    #   config.current_user do |controller|
    #     controller.current_user
    #   end
    #
    # @return [void]
    def current_user(&block)
      @current_user_block = block
    end

    # Labels the users of the audit log page. Called once per page with the
    # id (as a String) of every user on it, so one query loads them all. With
    # database storage the page only has that id; with memory storage the
    # label replaces the user's email or name. Users it does not label
    # (deleted ones), and all users when it raises, keep the default: the id
    # with database storage, the email or name with memory storage.
    #
    # @yield [identifiers] Block that returns the label of each user
    # @yieldparam identifiers [Array<String>] Distinct, non-blank user identifiers
    # @yieldreturn [Hash{String, Integer => String}] Label by user identifier
    #
    # @example Label users by email
    #   config.audit_user_labels do |identifiers|
    #     User.where(id: identifiers).pluck(:id, :email).to_h
    #   end
    #
    # @example Label users with a display method
    #   config.audit_user_labels do |identifiers|
    #     AdminUser.where(id: identifiers).to_h { |user| [user.id, user.display_name] }
    #   end
    #
    # @return [void]
    # @see IronAdmin::AuditLog.user_labels
    def audit_user_labels(&block)
      @audit_user_labels_block = block
    end

    # Registers a block called with one event after a resource change.
    #
    # Create, update and destroy call it after a successful save. A custom
    # action, a bulk action and an import call it after the resource transaction
    # commits, or immediately when there is no transaction. The import's action
    # is +:create+ or +:update+.
    #
    # The event has these readers:
    # * +user+ — +iron_admin_current_user+
    # * +action+ — +:create+, +:update+ or +:destroy+ for CRUD. For a custom
    #   action, +event.action+ is the String URL segment (+params[:action_name]+).
    #   For a bulk action, it is the Symbol passed to +bulk_action+. Compare with
    #   +event.action.to_s+. An import is +:create+ or +:update+
    # * +resource+ — the resource class name as a String, not the class
    # * +record_id+ — +record.id.to_s+
    # * +changes+ — a Hash of the saved changes. Password fields and the host's
    #   +filter_parameters+ are replaced with +"[FILTERED]"+
    # * +ip_address+ — +request.remote_ip+
    #
    # @yield [event] Block called with the event
    # @yieldparam event [OpenStruct] The event described above
    #
    # @example Record the event
    #   config.on_action do |event|
    #     AuditTrail.create!(
    #       action: event.action,
    #       resource: event.resource,
    #       record_id: event.record_id,
    #       user_id: event.user&.id
    #     )
    #   end
    #
    # @return [void]
    def on_action(&block)
      @on_action_block = block
    end

    # Configures the default theme: the one {#default_theme} names, else Neutral.
    #
    # @yieldparam theme [IronAdmin::Configuration::Theme] The default theme
    # @return [IronAdmin::Configuration::Theme] The default theme
    #
    # @example
    #   config.theme { |t| t.btn_primary = "bg-blue-600 text-white" }
    def theme
      default = find_theme(default_theme) || @themes.fetch(NEUTRAL_THEME)
      yield default if block_given?
      default
    end

    # @return [IronAdmin::Configuration::Theme] The default theme, as {#theme} returns it
    def theme_config
      theme
    end

    # Registers a theme that starts from the Neutral values and yields it.
    # Registering a name the app already owns replaces that theme and records
    # the app as its owner. A name a plugin owns raises {PluginError} before
    # anything is replaced. A blank name raises ArgumentError. A Symbol, a
    # String and any other case are the same name. The theme and its owner are
    # stored only after the block returns.
    #
    # @param name [Symbol, String] Cookie value
    # @param label [String] Switcher text
    # @return [IronAdmin::Configuration::Theme]
    # @raise [ArgumentError] The name is blank
    # @raise [IronAdmin::PluginError] A plugin already owns the name
    # @see IronAdmin::Plugin::Registration#theme
    def register_theme(name, label: name.to_s.titleize, &)
      key = theme_name!(name)
      refuse_foreign_theme!(key, :app)
      write_theme(key, label, :app, &)
    end

    # Registers a theme owned by a plugin. The same +plugin_name+ on a later
    # activation keeps the theme object: the block is not called again, so an
    # adjustment the app made stays until the process restarts.
    #
    # +plugin_name+ is a logical identity, not a proof that two implementations
    # are the same. Another plugin class that declares it is the same owner.
    #
    # @api private
    # @param plugin_name [#to_s] {IronAdmin::Plugin.plugin_name} of the owner
    # @param name [Symbol, String] Cookie value
    # @param label [String] Switcher text
    # @return [IronAdmin::Configuration::Theme]
    # @raise [IronAdmin::PluginError] Another owner already has the name
    # @raise [ArgumentError] The name is blank
    def register_plugin_theme(plugin_name, name, label: name.to_s.titleize, &)
      key = theme_name!(name)
      owner = plugin_name.to_s
      return @themes.fetch(key) if @theme_owners[key] == owner

      refuse_foreign_theme!(key, owner)
      write_theme(key, label, owner, &)
    end

    # @return [Hash{Symbol => IronAdmin::Configuration::Theme}] Registered themes by name: the
    #   default theme first, then the others in registration order
    def themes
      default = find_theme(default_theme)
      default ? { default.name => default }.merge(@themes) : @themes.dup
    end

    # @param name [Symbol, String] Name of the theme used when no registered theme resolves
    # @return [void]
    # @raise [ArgumentError] If the name is blank
    def default_theme=(name)
      @default_theme = theme_name!(name)
    end

    # Sets the block that names each request's theme, which by default is the
    # {THEME_COOKIE} cookie, and returns the resolver.
    #
    # @yieldparam request [ActionDispatch::Request] The current request
    # @yieldreturn [Symbol, String, nil] Name of a registered theme
    # @return [Proc] The resolver
    def theme_resolver(&block)
      @theme_resolver = block if block
      @theme_resolver
    end

    # @param request [ActionDispatch::Request] The current request
    # @return [IronAdmin::Configuration::Theme] The theme {#theme_resolver} names, else the
    #   default theme (also when the resolver raises, which is logged)
    def resolve_theme(request)
      theme_for(theme_resolver.call(request))
    rescue StandardError => e
      log_theme_resolver_error(e)
      theme
    end

    # @param name [Symbol, String, nil] Name of a theme
    # @return [IronAdmin::Configuration::Theme] The theme registered under the name, else the default theme
    def theme_for(name)
      find_theme(name) || theme
    end

    # @param name [Symbol, String, nil] Name of a theme. A String that is not valid UTF-8 is ignored
    # @return [IronAdmin::Configuration::Theme, nil] The theme registered under the name, else nil
    def find_theme(name)
      text = name.to_s
      return unless text.valid_encoding?
      return if text.strip.empty?

      @themes[theme_name!(name)]
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

    private

    def theme_name!(name)
      text = name.to_s
      raise ArgumentError, "IronAdmin theme name must not be blank, got #{name.inspect}" if text.strip.empty?

      text.downcase.to_sym
    end

    def refuse_foreign_theme!(key, claimant)
      owner = @theme_owners[key]
      return if owner.nil? || owner == claimant

      raise PluginError, theme_conflict_message(key, claimant, owner)
    end

    def write_theme(key, label, owner)
      theme = Theme.new(name: key, label: label)
      yield theme if block_given?
      @themes[key] = theme
      @theme_owners[key] = owner
      theme
    end

    def theme_conflict_message(key, claimant, owner)
      "Cannot register theme #{key.inspect} for #{theme_owner_phrase(claimant)}: " \
        "#{theme_owner_phrase(owner)} already registered it. " \
        "Rename one theme, or remove one registration."
    end

    def theme_owner_phrase(owner)
      return "the app" if owner == :app

      "plugin #{owner.inspect}"
    end

    def log_theme_resolver_error(error)
      return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

      Rails.logger.warn("[IronAdmin] theme_resolver raised #{error.class}: #{error.message}; using the default theme")
    end
  end
end
