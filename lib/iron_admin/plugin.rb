# frozen_string_literal: true

require "iron_admin/plugin/registration"

module IronAdmin
  # Base class for IronAdmin community/extension plugins.
  #
  # A plugin is a small declarative wrapper — usually shipped inside an
  # external Rails gem — that hooks its extensions into a host application's
  # IronAdmin install. Subclass this, declare metadata, and describe what to
  # register in a {.setup} block. The block runs against a
  # {Plugin::Registration} facade when the plugin is activated, so plugin code
  # never depends on IronAdmin's internal registry classes directly.
  #
  # @example A minimal plugin
  #   module IronAdminReports
  #     class Plugin < IronAdmin::Plugin
  #       plugin_name "iron_admin_reports"
  #       plugin_version "1.2.0"
  #       requires_iron_admin ">= 0.6", "< 2.0"
  #
  #       setup do |admin|
  #         admin.menu_item label: "Reports", path: "/admin/reports",
  #                         icon: "chart-bar", group: "Analytics", priority: 20
  #         admin.component :navbar, IronAdminReports::NavbarComponent
  #       end
  #     end
  #   end
  #
  #   # In the host app's config/initializers/iron_admin.rb:
  #   IronAdmin.register_plugin(IronAdminReports::Plugin)
  #
  # @see IronAdmin.register_plugin
  # @see IronAdmin::PluginRegistry
  # @see IronAdmin::Plugin::Registration
  class Plugin
    class << self
      # Declares (or reads) the plugin's unique identifier.
      #
      # @param value [String, nil] The plugin name when setting
      # @return [String] The plugin name
      def plugin_name(value = nil)
        @plugin_name = value.to_s if value
        @plugin_name || name.to_s
      end

      # Declares (or reads) the plugin's own version string.
      #
      # @param value [String, nil] The version when setting
      # @return [String, nil] The plugin version
      def plugin_version(value = nil)
        @plugin_version = value.to_s if value
        @plugin_version
      end

      # Declares the IronAdmin version constraint this plugin supports.
      #
      # Accepts the same syntax as a gemspec dependency (one or more
      # RubyGems requirement strings). Checked at activation time against
      # {IronAdmin::VERSION}.
      #
      # @param constraints [Array<String>] RubyGems requirement strings
      # @return [Gem::Requirement, nil] The parsed requirement
      def requires_iron_admin(*constraints)
        @iron_admin_requirement = Gem::Requirement.new(*constraints) unless constraints.empty?
        @iron_admin_requirement
      end

      # Registers the setup block that describes what the plugin contributes.
      #
      # The block receives a {Plugin::Registration} facade when the plugin is
      # activated. Only one setup block is supported per plugin.
      #
      # @yield [registration] The registration facade
      # @yieldparam registration [IronAdmin::Plugin::Registration]
      # @return [void]
      def setup(&block)
        @setup_block = block
      end

      # Verifies this plugin is compatible with the running IronAdmin version.
      #
      # @param iron_admin_version [String] Version to check against
      # @return [Boolean]
      def compatible_with?(iron_admin_version = IronAdmin::VERSION)
        requirement = requires_iron_admin
        return true if requirement.nil?

        requirement.satisfied_by?(Gem::Version.new(iron_admin_version))
      end

      # Runs the plugin's setup block against a fresh registration facade.
      #
      # @raise [IronAdmin::IncompatiblePluginError] When the running
      #   IronAdmin version does not satisfy {.requires_iron_admin}
      # @return [void]
      def activate!
        unless compatible_with?
          raise IncompatiblePluginError,
                "Plugin #{plugin_name} requires IronAdmin #{requires_iron_admin} " \
                "but #{IronAdmin::VERSION} is loaded"
        end

        @setup_block&.call(Registration.new(self))
      end
    end
  end
end
