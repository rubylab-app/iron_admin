# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Per-resource component overrides, which win over the global ones in
    # {IronAdmin::Configuration::Components}.
    module ComponentOverridable
      extend ActiveSupport::Concern

      included do
        class_attribute :component_overrides, default: {}
      end

      class_methods do
        # Replaces part of this resource's pages with your own ViewComponent.
        #
        # @param name [Symbol] One of {IronAdmin::Configuration::Components::RESOURCE_SLOTS}
        # @param klass [Class, String] A ViewComponent::Base subclass, or its class name
        # @raise [ArgumentError] Unknown slot or invalid component
        # @example
        #   component :table, CustomUserTableComponent
        # @return [void]
        def component(name, klass)
          slot = name.to_sym
          components = IronAdmin::Configuration::Components
          unless components::RESOURCE_SLOTS.include?(slot)
            raise ArgumentError, unknown_component_slot_message(slot) unless components::SLOTS.key?(slot)

            raise ArgumentError, "#{slot.inspect} applies to every page; set config.components.#{slot} instead"
          end

          self.component_overrides = component_overrides.merge(slot => components.validate!(slot, klass))
        end

        # @param name [Symbol] Slot name
        # @return [Class, nil] This resource's override for +name+, if any
        def component_override(name)
          component = component_overrides[name.to_sym]
          component && IronAdmin::Configuration::Components.component_class(name.to_sym, component)
        end

        private

        def unknown_component_slot_message(slot)
          valid = IronAdmin::Configuration::Components::RESOURCE_SLOTS.map(&:inspect).join(", ")
          "Unknown resource component slot #{slot.inspect}. Valid slots: #{valid}"
        end
      end
    end
  end
end
