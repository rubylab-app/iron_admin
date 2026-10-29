# frozen_string_literal: true

module IronAdmin
  # Registry that tracks all registered resource classes.
  #
  # Resources are automatically registered when they are defined (via the
  # inherited hook in {Resource}). This registry provides methods to look up
  # resources by name and retrieve them for the sidebar menu.
  #
  # @example Find a resource by name
  #   resource = IronAdmin::ResourceRegistry.find("users")
  #   resource.model  #=> User
  #
  # @example List all resources
  #   IronAdmin::ResourceRegistry.all.each do |resource|
  #     puts resource.label
  #   end
  #
  # @see IronAdmin::Resource
  class ResourceRegistry
    class << self
      # Registers a resource class in the registry.
      #
      # Called automatically by `Resource.inherited`. The class is added to
      # the registry hash **before** any model introspection so that even
      # if soft-delete registration raises, the resource is still
      # discoverable (and will be retried by {.finalize!}).
      #
      # The eager soft-delete call fires with whatever `adapter_class` is
      # set at inheritance time, which for non-AR resources is the parent
      # default (`:active_record`) — that's wrong but expected. The error
      # is swallowed and {.finalize!} re-runs with the correct adapter
      # after the class body has finished evaluating.
      #
      # A class whose name equals the name of a class already stored is a
      # reloaded version of it: this replaces that entry in the remembered
      # list and in the registry, and it is not a collision. Two different
      # classes that compute the same resource name keep the first one
      # registered. The other stays out of the registry, and {.finalize!}
      # logs that collision once. Before 0.8 the last class registered
      # replaced the previous one. The registry key is computed before the
      # class is remembered, so a class that has no key (an anonymous class
      # whose model cannot be named) raises here and is not remembered.
      #
      # @param resource_class [Class] The resource class to register
      # @return [Class] The registered resource class
      def register(resource_class)
        # Compute the key before remembering the class. An anonymous class
        # with no model raises here; remembering it first would make every
        # later {.finalize!} raise inside {#rekey_resources!}. The key is
        # provisional until {.finalize!}: `inherited` runs before the
        # class body sets `model_class_override` and `resource_name`.
        registry_key_for(resource_class)
        remember_resource(resource_class)
        store_resource(resource_class)
        begin
          resource_class.register_soft_delete_features
        rescue StandardError
          # Swallow eager-registration failures silently — `finalize!`
          # retries with the correct adapter once the class body has
          # fully evaluated, and logs there.
          nil
        end
        resource_class
      end

      # Runs every post-load registration step on every registered resource.
      #
      # Called by the engine's `to_prepare` block once all resource classes
      # have been eager-loaded and their bodies have fully evaluated. By
      # then `adapter_class`, `model_class_override`, etc. are set
      # correctly, so model introspection through the adapter is safe.
      #
      # Soft-delete registration is idempotent; resources that succeeded
      # eagerly during {.register} are skipped here. Failures are logged
      # and swallowed per resource so a single broken resource (missing
      # model class, unreachable DB, etc.) doesn't take down the boot.
      #
      # The cached `@adapter` instance is invalidated for every resource
      # before re-running registration. The eager `Resource.adapter` call
      # at inheritance time memoized an `Adapters::ActiveRecord.new(model)`
      # — built with whatever `adapter_class` defaulted to before the
      # class body's `self.adapter_class = :mongoid` (or `:http`) had
      # taken effect. Without this invalidation, every subsequent
      # `Resource.adapter` would keep returning that stale AR adapter
      # and Mongoid/HTTP resources would 500 with `undefined method
      # 'columns' for <MongoidModel>`.
      #
      # The registry is also re-keyed by each resource's final
      # {Resource.resource_name}. A reloaded class (the same name) already
      # replaced its stale entry in {.register}. Two different classes that
      # still share a name keep the first one registered; the other is
      # logged once here and left out.
      #
      # @return [void]
      def finalize!
        rekey_resources!
        all.each do |resource_class|
          resource_class.instance_variable_set(:@adapter, nil)
          resource_class.register_soft_delete_features
        rescue StandardError => e
          warn_finalize_failure(resource_class, e)
        end
      end

      # Returns all registered resource classes.
      #
      # @return [Array<Class>] All registered resource classes
      def all
        resources.values
      end

      # Finds a resource class by its name.
      #
      # @param resource_name [String] The pluralized resource name (e.g., "users")
      # @return [Class, nil] The resource class, or nil if not found
      #
      # @example
      #   IronAdmin::ResourceRegistry.find("users")  #=> UserResource
      #   IronAdmin::ResourceRegistry.find("orders") #=> OrderResource
      def find(resource_name)
        resources[resource_name]
      end

      # Returns resources grouped by their menu group.
      #
      # Resources without a group are placed in "Resources".
      #
      # @return [Hash{String => Array<Class>}] Resources grouped by menu section
      #
      # @example
      #   {
      #     "Users" => [UserResource, AdminResource],
      #     "Commerce" => [OrderResource, ProductResource],
      #     "Resources" => [SettingResource]
      #   }
      def grouped
        all.group_by { |r| r.menu_options[:group] || "Resources" }
      end

      # Returns resources sorted by menu priority.
      #
      # Lower priority values appear first. Resources without a priority
      # default to 999.
      #
      # @return [Array<Class>] Sorted resource classes
      def sorted
        all.sort_by { |r| r.menu_options[:priority] || 999 }
      end

      # Clears all registered resources.
      #
      # @api private
      # @return [void]
      def reset!
        @resources = {}
        @registered_classes = []
      end

      private

      def resources
        @resources ||= {}
      end

      def registered_classes
        @registered_classes ||= []
      end

      def remember_resource(resource_class)
        index = registered_classes.index { |stored| same_registered_class?(stored, resource_class) }
        if index
          registered_classes[index] = resource_class
        else
          registered_classes << resource_class
        end
      end

      # A reloaded class (the same name) replaces its previous entry, including
      # a move to a new key. A different class leaves the first occupant of the
      # key in place and stays in {#registered_classes} so {.finalize!} can
      # place it once its resource name is final.
      def store_resource(resource_class)
        key = registry_key_for(resource_class)
        resources.delete_if { |_stored_key, stored| same_registered_class?(stored, resource_class) }
        resources[key] ||= resource_class
      end

      # Same object, or a reload of it: another class object with the same name.
      # Anonymous classes have no name, so only the same object matches.
      def same_registered_class?(stored, resource_class)
        stored.equal?(resource_class) || (resource_class.name && stored.name == resource_class.name)
      end

      def rekey_resources!
        rebuilt = {}
        registered_classes.each do |resource_class|
          key = registry_key_for(resource_class)
          occupant = rebuilt[key]
          if occupant && occupant != resource_class
            log_registry_collision(occupant, resource_class, key)
          else
            rebuilt[key] = resource_class
          end
        end
        @resources = rebuilt
      end

      def log_registry_collision(kept, skipped, key)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        Rails.logger.error(
          "[IronAdmin] #{skipped.name} was not registered under \"#{key}\" because " \
          "#{kept.name} already uses that resource name. " \
          "Define def self.resource_name = \"a_unique_name\" on one of them."
        )
      end

      # Builds the registry key. `resource_name` may raise before the class
      # body has set the adapter, so fall back to the class path. The
      # derivation matches {Resource.resource_name}.
      def registry_key_for(resource_class)
        resource_class.resource_name
      rescue StandardError
        name = resource_class.name
        raise if name.nil?

        name.delete_prefix("IronAdmin::Resources::").delete_suffix("Resource").underscore.tr("/", "_").pluralize
      end

      def warn_finalize_failure(resource_class, error)
        return unless defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger

        Rails.logger.warn(
          "[IronAdmin] Could not finalize #{resource_class.name}: #{error.class} (#{error.message})"
        )
      end
    end
  end
end
