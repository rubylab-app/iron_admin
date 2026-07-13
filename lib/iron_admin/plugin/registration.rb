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

      # Overrides one of IronAdmin's global UI components.
      #
      # Delegates to {IronAdmin::Configuration::Components}. Valid names match
      # its accessors (e.g. +:table+, +:form+, +:navbar+, +:sidebar+,
      # +:shell+, +:search+, +:filter_bar+).
      #
      # @param name [Symbol] The component slot to override
      # @param component_class [Class] The replacement ViewComponent class
      # @raise [ArgumentError] If +name+ is not a known component slot
      # @return [Class] The registered component class
      def component(name, component_class)
        components = IronAdmin.configuration.components
        writer = "#{name}="
        raise ArgumentError, "Unknown component slot: #{name.inspect}" unless components.respond_to?(writer)

        components.public_send(writer, component_class)
        component_class
      end

      # Registers a custom field type renderer.
      #
      # Delegates to {IronAdmin::FieldTypeRegistry}. Accepts the same block
      # DSL as {IronAdmin.register_field_type}.
      #
      # @param type_name [Symbol] The field type identifier
      # @yield Field type configuration block
      # @return [void]
      def field_type(type_name, &)
        FieldTypeRegistry.register(type_name, &)
      end
    end
  end
end
