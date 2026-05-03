# frozen_string_literal: true

require "active_support/concern"

module IronAdmin
  module Concerns
    # Adds the auto-registered soft-delete features (`with_deleted` /
    # `only_deleted` scopes and the `:restore` action) when the underlying
    # model has a `deleted_at` column.
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
          column_sym = column.to_sym

          self._soft_delete_scopes = [
            { name: :with_deleted, scope: -> { unscope(where: column_sym) }, default: false },
            { name: :only_deleted, scope: -> { unscope(where: column_sym).where.not(column => nil) }, default: false },
          ]

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
    end
  end
end
