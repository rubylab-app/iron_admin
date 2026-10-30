# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Per-resource switch for the record counts on scope tabs.
    #
    # A resource that never calls {ScopeCountDsl#scope_counts} follows
    # {Configuration#scope_counts}. Extracted from {IronAdmin::Resource} so
    # the parent class stays under the Metrics/ClassLength budget.
    module ScopeCountable
      extend ActiveSupport::Concern

      # The class methods {IronAdmin::Resource} uses to turn scope-tab counts
      # on or off. A named module, because YARD does not document methods
      # defined inside +class_methods+.
      module ScopeCountDsl
        # Turns scope-tab counts on or off for this resource.
        #
        # Each counted scope costs one query on the index. +false+ draws
        # every tab with its name only. Omit the call to follow
        # {Configuration#scope_counts}.
        #
        # @param enabled [Boolean] +false+ turns the counts off. Omit it, or
        #   pass +true+, to turn them on for this resource.
        # @return [void]
        # @example
        #   module IronAdmin
        #     module Resources
        #       class UserResource < IronAdmin::Resource
        #         scope_counts true
        #       end
        #     end
        #   end
        def scope_counts(enabled = nil)
          self._scope_counts = enabled.nil? || enabled
        end

        # @return [Boolean] whether this resource's index counts each scope
        def scope_counts_enabled?
          return _scope_counts unless _scope_counts.nil?

          IronAdmin.configuration.scope_counts
        end
      end

      included do
        # +nil+ follows the global setting. +true+ or +false+ overrides it.
        class_attribute :_scope_counts, default: nil
      end

      class_methods do
        include ScopeCountDsl
      end
    end
  end
end
