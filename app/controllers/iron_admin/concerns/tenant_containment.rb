# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Rolls a write back when the saved record would sit outside the tenant.
    module TenantContainment
      extend ActiveSupport::Concern

      private

      # Runs a write and rolls it back when the record leaves the tenant.
      #
      # With no tenant scope configured, returns the block's value. Otherwise
      # the block runs in a transaction. When the write succeeds and the record
      # or a persisted nested child is outside the tenant scope, an error is
      # added on +:base+, the result becomes +false+, and {IronAdmin::Rollback}
      # rolls the transaction back so nothing is written.
      #
      # @param record [Object] record being created or updated
      # @yield the write to run inside the transaction
      # @return [Boolean] whether the write succeeded and stayed in the tenant
      def write_within_tenant(record)
        return yield unless IronAdmin::TenantScope.configured?

        outcome = nil
        adapter.transaction do
          adapter.wrap_rollback do
            outcome = yield
            if outcome && !record_within_tenant?(record)
              record.errors.add(:base, I18n.t("iron_admin.resources.errors.outside_tenant"))
              outcome = false
              raise IronAdmin::Rollback
            end
          end
        end
        outcome
      end

      # Whether +record+ and its persisted nested children are inside the tenant.
      #
      # +record+ must be found in {#base_scope} by its primary key. A composite
      # key is the values joined with +"_"+, which is what {#find_record} accepts.
      # Each persisted child of +@resource_class.nested_associations+ (a has_one
      # child included) must be found in +TenantScope.apply(child.class.all)+ by
      # that child's primary key.
      #
      # @param record [Object]
      # @return [Boolean]
      def record_within_tenant?(record)
        return false unless found_in_scope?(base_scope, record)

        nested_children_within_tenant?(record)
      end

      def found_in_scope?(scope, record)
        find_record(scope, primary_key_value(record))
        true
      rescue IronAdmin::RecordNotFound
        false
      end

      # @param record [Object]
      # @return [String, Object] composite ids joined with +"_"+, or the raw key
      def primary_key_value(record)
        key = adapter.primary_key
        return key.map { |column| record.public_send(column) }.join("_") if key.is_a?(Array)

        record.public_send(key)
      end

      def nested_children_within_tenant?(record)
        @resource_class.nested_associations.all? do |nested|
          Array(record.public_send(nested.name)).all? { |child| child_inside_tenant?(child) }
        end
      end

      def child_inside_tenant?(child)
        return true if child.nil? || (child.respond_to?(:persisted?) && !child.persisted?)

        scope = IronAdmin::TenantScope.apply(child.class.all)
        child_scope_includes?(scope, child)
      end

      def child_scope_includes?(scope, child)
        key = child.class.primary_key
        located = Array(key).reduce(scope) do |current, column|
          adapter.filter(current, column.to_sym, child.public_send(column))
        end.first
        !located.nil?
      end
    end
  end
end
