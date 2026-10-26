# frozen_string_literal: true

module IronAdmin
  class Configuration
    # Global component overrides, also set by plugins. A resource's override
    # (see {IronAdmin::Concerns::ComponentOverridable}) wins over these; a slot
    # with neither keeps IronAdmin's built-in markup.
    #
    # @example
    #   config.components.navbar = "MyNavbarComponent"
    class Components
      # Keyword arguments IronAdmin passes to each slot's component. A component
      # gets the ones its +initialize+ declares (all of them with +**options+)
      # and must not require others. +fields+ and +filters+ are the visible ones;
      # +flash+ is the request's flash.
      SLOTS = {
        shell: %i[current_user],
        navbar: %i[current_user title],
        sidebar: %i[current_user],
        flash: %i[flash current_user],
        table: %i[records fields resource_class current_user current_sort current_direction scope query base_url],
        form: %i[record fields resource_class url current_user],
        filter_bar: %i[filters resource_class form_url scope query active_count current_user],
        search: %i[resource_class form_url value placeholder hidden_params current_user],
      }.freeze

      # Slots a resource can override with +component+.
      RESOURCE_SLOTS = %i[table form filter_bar search].freeze

      # Built-in components. Slots missing here render inline markup from the views.
      DEFAULTS = {
        shell: "IronAdmin::Layout::ShellComponent",
        navbar: "IronAdmin::Layout::NavbarComponent",
        sidebar: "IronAdmin::Layout::SidebarComponent",
        flash: "IronAdmin::Layout::FlashComponent",
      }.freeze

      # Keyword arguments a {#fields} component receives.
      FIELD_ARGUMENTS = %i[form field record].freeze

      # A reader and a validating writer per slot; each holds a class, a class name or nil.
      SLOTS.each_key do |slot|
        attr_reader slot

        define_method(:"#{slot}=") do |component|
          instance_variable_set(:"@#{slot}", self.class.validate!(slot, component))
        end
      end

      # Field type => component (class or class name) that replaces the form
      # input of every field of that type, built-in types included.
      #
      # @return [Hash{Symbol => Class, String}]
      attr_reader :fields

      # Creates a new Components configuration with defaults.
      def initialize
        @fields = {}
      end

      # The resource's override, else the global one, else the built-in component.
      #
      # @param slot [Symbol] One of {SLOTS}
      # @return [Class, nil] nil when the slot renders inline markup
      # @raise [ArgumentError] Invalid slot or override
      def resolve(slot, resource_class: nil)
        slot = slot.to_sym
        raise ArgumentError, "Unknown component slot #{slot.inspect}" unless SLOTS.key?(slot)

        component = resource_class&.component_override(slot) if RESOURCE_SLOTS.include?(slot)
        component ||= public_send(slot) || DEFAULTS[slot]
        component && self.class.component_class(slot, component)
      end

      # @param slot [Symbol] One of {SLOTS}
      # @param arguments [Hash] The slot's keywords; +:resource_class+ also picks the resource's override
      # @return [ViewComponent::Base, nil] nil when the slot renders inline markup
      def build(slot, **arguments)
        component_class = resolve(slot, resource_class: arguments[:resource_class])
        component_class && self.class.instantiate(component_class, arguments)
      end

      # @api private
      # @return [Array<Symbol>] Field types that have a component in {#fields}
      def field_types
        fields.filter_map { |type, component| type.to_sym if component }
      end

      # @param field [IronAdmin::Field] The field being rendered
      # @param arguments [Hash] +form:+ and +record:+
      # @return [ViewComponent::Base, nil] nil when the field's type has no component
      def build_field(field, **arguments)
        component = fields[field.type.to_sym] || fields[field.type.to_s]
        return unless component

        component_class = self.class.component_class("fields[#{field.type.to_sym.inspect}]", component, FIELD_ARGUMENTS)
        self.class.instantiate(component_class, arguments.merge(field: field))
      end

      class << self
        # @api private
        # Checks a component class when it is set; a class name is checked when resolved.
        #
        # @return [Class, String, nil] +component+
        # @raise [ArgumentError] If +component+ cannot render the slot
        def validate!(slot, component, arguments = SLOTS.fetch(slot.to_sym))
          case component
          when nil, String then component
          when Class then check_component_class!(slot, component, arguments)
          else
            raise ArgumentError, "IronAdmin component override #{label(slot)} must be a ViewComponent::Base " \
                                 "subclass or its class name, got #{component.inspect}"
          end
        end

        # @api private
        # @return [Class] The checked class; a class name is looked up first
        # @raise [NameError] If a class name is not defined
        def component_class(slot, component, arguments = SLOTS.fetch(slot.to_sym))
          component = component.constantize if component.is_a?(String)
          validate!(slot, component, arguments)
        end

        # @api private
        # @return [ViewComponent::Base] +component_class+ built with the keywords its initialize accepts
        def instantiate(component_class, arguments)
          parameters = component_class.instance_method(:initialize).parameters
          return component_class.new(**arguments) if parameters.any? { |type, _| type == :keyrest }

          accepted = parameters.filter_map { |type, name| name if %i[key keyreq].include?(type) }
          component_class.new(**arguments.slice(*accepted))
        end

        private

        def check_component_class!(slot, component, arguments)
          unless component < ViewComponent::Base
            raise ArgumentError, "IronAdmin component override #{label(slot)} must be a ViewComponent::Base " \
                                 "subclass, got #{component}"
          end

          parameters = component.instance_method(:initialize).parameters
          if parameters.any? { |type, _| type == :req }
            raise ArgumentError, "#{component} cannot render #{label(slot)}: its initialize takes a positional " \
                                 "argument, but IronAdmin passes only keyword arguments"
          end

          missing = parameters.filter_map { |type, name| name if type == :keyreq } - arguments
          return component if missing.empty?

          raise ArgumentError, "#{component} cannot render #{label(slot)}: its initialize requires " \
                               "#{missing.map(&:inspect).join(", ")}, but IronAdmin passes " \
                               "#{arguments.map(&:inspect).join(", ")}"
        end

        def label(slot)
          slot.is_a?(Symbol) ? slot.inspect : slot.to_s
        end
      end
    end
  end
end
