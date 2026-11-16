# frozen_string_literal: true

require "active_support/concern"

module IronAdmin
  module Concerns
    # Adds the auto-registered soft-delete features when the underlying
    # model has a `deleted_at` column. `:restore` is always registered.
    # `with_deleted` and `only_deleted` are registered only when
    # `adapter.supports_soft_delete_tabs?` is true.
    #
    # Extracted from `IronAdmin::Resource` so the registration logic can
    # evolve independently — and so the parent class stays under the
    # configured `Metrics/ClassLength` budget.
    module SoftDeletable
      extend ActiveSupport::Concern

      class_methods do
        # @return [Boolean] True if the model has a `deleted_at` column.
        def soft_delete?
          adapter.has_column?(soft_delete_column)
        end

        # @return [String] Column name used for soft-delete tracking.
        def soft_delete_column
          "deleted_at"
        end

        # Idempotently registers soft-delete scopes and the `:restore`
        # action on this resource. Tolerates a missing/unreachable DB at
        # boot time so `bin/rails db:create` and short outages during
        # deploy don't crash boot — the skip is logged. Safe to call
        # multiple times: the negative result is cached too so we don't
        # re-introspect the schema on every register / finalize! cycle.
        #
        # @return [void]
        def register_soft_delete_features
          return if @soft_delete_features_registered
          return @soft_delete_features_registered = true unless soft_delete?

          column = soft_delete_column
          # ActiveRecord can run these bodies. Other adapters cannot (no
          # unscope), so counting them would fail on every index.
          skip = adapter.is_a?(IronAdmin::Adapters::ActiveRecord) ? {} : { count: false }
          self._soft_delete_scopes = SoftDeletable.scope_tabs(self, column, skip)

          action :restore, icon: "arrow-path", condition: ->(record) { record.public_send(column).present? } do |record|
            record.update(column => nil)
          end

          @soft_delete_features_registered = true
        rescue *IronAdmin.db_unreachable_exceptions => e
          msg = "[IronAdmin] Skipping soft-delete features for #{name}: #{e.class} (#{e.message})"
          (defined?(Rails) ? Rails.logger : nil)&.warn(msg)
          nil
        end
      end

      # The `with_deleted` and `only_deleted` tabs, or none when the
      # resource's adapter cannot run them. Zero-arity bodies:
      # Relation#merge and Scopeable#apply_resource_scope run them with
      # instance_exec and no argument, so self is the relation. The adapter
      # is resolved at call time; registration clears `@adapter`.
      #
      # @api private
      # @param resource [Class] the resource class
      # @param column [String] the soft-delete column
      # @param skip [Hash] extra keys for each tab (`{ count: false }` or `{}`)
      # @return [Array<Hash>]
      def self.scope_tabs(resource, column, skip)
        return [] unless resource.adapter.supports_soft_delete_tabs?

        [
          { name: :with_deleted, scope: -> { resource.adapter.unscope_column(self, column) }, default: false, **skip },
          { name: :only_deleted, scope: -> { resource.adapter.only_soft_deleted(self, column) }, default: false, **skip },
        ]
      end
    end
  end
end
