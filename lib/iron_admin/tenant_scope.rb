# frozen_string_literal: true

module IronAdmin
  # Single entry point for the configured tenant scope.
  #
  # Reads and records built from a scope both go through {.apply}, so a
  # multi-tenant application cannot skip the filter on one surface.
  module TenantScope
    module_function

    # Returns +relation+ scoped to the current tenant.
    #
    # When no tenant scope is configured, +relation+ is returned unchanged.
    #
    # @param relation [Object] Query relation or scope to filter
    # @return [Object] The block's relation, or +relation+ itself
    def apply(relation)
      return relation unless configured?

      IronAdmin.configuration.tenant_scope_block.call(relation)
    end

    # Whether {IronAdmin::Configuration#tenant_scope} was configured.
    #
    # @return [Boolean]
    def configured?
      !IronAdmin.configuration.tenant_scope_block.nil?
    end
  end
end
