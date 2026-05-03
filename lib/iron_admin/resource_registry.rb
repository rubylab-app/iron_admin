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
      # @param resource_class [Class] The resource class to register
      # @return [Class] The registered resource class
      def register(resource_class)
        resources[resource_class.resource_name] = resource_class
        resource_class.register_soft_delete_features
        resource_class
      rescue StandardError
        # Swallow eager-registration failures — `finalize!` retries with
        # the correct adapter once the class body has fully evaluated.
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
      # @return [void]
      def finalize!
        all.each do |resource_class|
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
      end

      private

      def resources
        @resources ||= {}
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
