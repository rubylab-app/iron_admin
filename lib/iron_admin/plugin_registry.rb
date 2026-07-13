# frozen_string_literal: true

module IronAdmin
  # Registry of {Plugin} classes activated in the host application.
  #
  # Plugins are registered explicitly (typically from a host initializer via
  # {IronAdmin.register_plugin}), unlike resources/tools which self-register on
  # inheritance. Explicit registration keeps activation ordering deterministic
  # and gives the host a single, auditable list of everything that extends its
  # admin panel.
  #
  # @see IronAdmin::Plugin
  # @see IronAdmin.register_plugin
  class PluginRegistry
    class << self
      # Registers and immediately activates a plugin.
      #
      # Registration is idempotent by {Plugin.plugin_name}: re-registering the
      # same plugin re-activates it (used on Rails +to_prepare+ reloads) rather
      # than adding a duplicate.
      #
      # @param plugin_class [Class] A subclass of {IronAdmin::Plugin}
      # @raise [IronAdmin::PluginError] If +plugin_class+ is not a Plugin subclass
      # @raise [IronAdmin::IncompatiblePluginError] If the plugin is incompatible
      # @return [Class] The registered plugin class
      def register(plugin_class)
        unless plugin_class.is_a?(Class) && plugin_class < IronAdmin::Plugin
          raise PluginError, "#{plugin_class.inspect} is not an IronAdmin::Plugin subclass"
        end

        plugins[plugin_class.plugin_name] = plugin_class
        plugin_class.activate!
        plugin_class
      end

      # Re-activates every registered plugin.
      #
      # Called by the engine on boot/reload so component overrides and menu
      # items survive the per-request configuration lifecycle. Activation is
      # idempotent, so repeated calls are safe.
      #
      # @return [void]
      def activate_all!
        all.each(&:activate!)
      end

      # @return [Array<Class>] All registered plugin classes
      def all
        plugins.values
      end

      # Finds a registered plugin by name.
      #
      # @param plugin_name [String] The plugin identifier
      # @return [Class, nil]
      def find(plugin_name)
        plugins[plugin_name.to_s]
      end

      # Clears all registered plugins.
      #
      # @api private
      # @return [void]
      def reset!
        @plugins = {}
      end

      private

      def plugins
        @plugins ||= {}
      end
    end
  end
end
