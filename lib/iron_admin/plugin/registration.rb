# frozen_string_literal: true

module IronAdmin
  class Plugin
    # Facade passed to a {Plugin.setup} block during activation.
    #
    # Registration exposes a small, stable surface for plugins to hook into
    # IronAdmin's extension points. It deliberately hides the concrete
    # registry/configuration classes so that internal refactors don't break
    # third-party plugins — this facade is the plugin API contract.
    #
    # == Implemented extension points (proof of concept)
    #
    # - {#menu_item}  — contribute a custom sidebar link
    # - {#component}  — override a global UI component
    # - {#field_type} — register a custom field type renderer
    # - {#theme}      — register a named theme
    #
    # == Planned extension points (design only — see docs/plugin-system-design.md)
    #
    # - +#adapter+     — register a data-source adapter
    # - +#load_path+   — contribute a Zeitwerk dir of resources/dashboards/tools
    # - +#on_action+   — subscribe to CRUD lifecycle events
    #
    # @see IronAdmin::Plugin
    class Registration
      # @param plugin [Class] The plugin class being activated
      def initialize(plugin)
        @plugin = plugin
      end

      # Contributes a custom link to the admin sidebar.
      #
      # @param label [String] Human-readable label
      # @param path [String] URL or path to link to
      # @param icon [String, nil] Optional heroicon name
      # @param group [String] Sidebar group heading (default "Plugins")
      # @param priority [Integer] Sort weight within the group
      # @return [IronAdmin::MenuItem] The registered item
      def menu_item(label:, path:, icon: nil, group: "Plugins", priority: 999)
        item = MenuItem.new(label: label, path: path, icon: icon, group: group, priority: priority)
        MenuRegistry.register(item)
      end

      # Same as +config.components.<name> = component_class+.
      #
      # @param name [Symbol] A key of {IronAdmin::Configuration::Components::SLOTS}
      # @param component_class [Class, String] A ViewComponent::Base subclass, or its class name
      # @raise [ArgumentError] Unknown slot or invalid component
      # @return [Class, String] The registered component
      def component(name, component_class)
        slot = name.to_s.to_sym
        raise ArgumentError, "Unknown component slot: #{name.inspect}" unless Configuration::Components::SLOTS.key?(slot)

        IronAdmin.configuration.components.public_send(:"#{slot}=", component_class)
        component_class
      end

      # Registers a custom field type renderer.
      #
      # Delegates to {IronAdmin::FieldTypeRegistry}. Accepts the same block
      # DSL as {IronAdmin.register_field_type}.
      #
      # Idempotent under re-activation: unlike component overrides (which are
      # re-applied on every +to_prepare+), field types live in a process-wide
      # registry that is not reset on reload, so re-registering an existing
      # type name is a no-op instead of raising.
      #
      # @param type_name [Symbol] The field type identifier
      # @yield Field type configuration block
      # @return [void]
      def field_type(type_name, &)
        return if FieldTypeRegistry.registered?(type_name)

        FieldTypeRegistry.register(type_name, &)
      end

      # Registers a theme that starts from the pristine Neutral values and yields it,
      # the same way {IronAdmin::Configuration#register_theme} does.
      #
      # The name is owned by this plugin's {IronAdmin::Plugin.plugin_name}. +plugin_name+ is a
      # logical identity, not a proof that two implementations are the same: another
      # plugin class that declares the same name is the same owner, and activating it
      # does not rebuild the theme.
      #
      # - A free name is registered, and this plugin recorded as its owner, only after
      #   the block returns. A block that raises leaves neither a theme nor an owner.
      # - Activating again (every Rails +to_prepare+) does nothing. The theme is not
      #   rebuilt, and its values and label are not applied again, so an adjustment the
      #   app made to the theme object stays until the process restarts.
      # - A name owned by another plugin, or by the app (Neutral and any
      #   +config.register_theme+), raises {IronAdmin::PluginError} before anything is
      #   replaced. The message names the theme and both owners. Rename one theme, or
      #   remove one registration.
      #
      # A Symbol, a String and any other case are the same name.
      #
      # @note EXPERIMENTAL — unstable until 1.0. The plugin API is not covered by the
      #   zero-breaking-changes invariant and may change before GA.
      #
      # @param name [Symbol, String] Theme name, also the value of the theme cookie
      # @param label [String] Switcher text (default: the titleized name)
      # @yield [theme] The new theme, and only the first time this plugin registers it
      # @yieldparam theme [IronAdmin::Configuration::Theme]
      # @return [IronAdmin::Configuration::Theme] The registered theme
      # @raise [IronAdmin::PluginError] Another owner already has the name
      # @raise [ArgumentError] The name is blank
      #
      # @example A theme plugin
      #   # lib/iron_admin/theme/high_contrast.rb (in the theme gem)
      #   module IronAdmin
      #     module Theme
      #       class HighContrast < IronAdmin::Plugin
      #         plugin_name "iron_admin-theme-high_contrast"
      #
      #         # A gem that ships CSS needs this engine_name, and
      #         # app/assets/tailwind/iron_admin_theme_high_contrast/engine.css.
      #         class Engine < Rails::Engine
      #           engine_name "iron_admin_theme_high_contrast"
      #         end
      #
      #         setup do |admin|
      #           admin.theme(:high_contrast, label: "High Contrast") do |theme|
      #             theme.btn_primary = "bg-black text-white hover:bg-zinc-800 " \
      #                                 "focus-visible:outline-2 focus-visible:outline-offset-2 " \
      #                                 "focus-visible:outline-black"
      #             theme.link = "text-black underline hover:text-zinc-800"
      #             theme.swatch = "rounded-full bg-black ring-2 ring-black"
      #           end
      #         end
      #       end
      #     end
      #   end
      #
      #   # In the host app's config/initializers/iron_admin.rb:
      #   IronAdmin.register_plugin(IronAdmin::Theme::HighContrast)
      def theme(name, label: name.to_s.titleize, &)
        IronAdmin.configuration.register_plugin_theme(@plugin.plugin_name, name, label: label, &)
      end
    end
  end
end
