# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Rolls a write back when the saved record would sit outside the tenant.
    module TenantContainment
      extend ActiveSupport::Concern

      include NestedTenantCheck

      private

      # Runs a write and keeps it inside the tenant.
      #
      # With no tenant scope configured, returns the block's value. Adapters
      # that support transactions run the block inside a transaction and roll
      # it back when the saved record or a persisted nested child is outside
      # the tenant. Adapters that cannot roll back verify an in-memory
      # candidate, including each nested row, and yield only when every
      # check is +:inside+.
      #
      # @param record [Object] record being created or updated
      # @param attrs [Hash, nil] update attributes, or +nil+ on create
      # @param submitted [Hash, nil] create params, read when +attrs+ is +nil+
      # @yield the write, skipped when a non-transactional check is not +:inside+
      # @return [Boolean, Object] +false+ when rejected, otherwise the block value
      def write_within_tenant(record, attrs = nil, submitted = nil, &)
        return yield unless IronAdmin::TenantScope.configured?
        return verify_then_write(record, attrs, submitted, &) unless adapter.supports_transactions?

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

      # Yields only when the parent and every nested row are inside the tenant.
      #
      # +:outside+ is outside the tenant. +:unknown+ means the adapter cannot
      # tell. Both add an error on +:base+ and skip the write. Nested rows come
      # from +attrs+, or from +submitted+ when +attrs+ is +nil+ (create).
      #
      # @param record [Object]
      # @param attrs [Hash, nil]
      # @param submitted [Hash, nil]
      # @yield the write
      # @return [Boolean, Object]
      def verify_then_write(record, attrs, submitted = nil)
        verdict = prewrite_verdict(record, attrs, submitted)
        return yield if verdict == :inside

        record.errors.add(:base, containment_error(verdict))
        false
      end

      # @param record [Object]
      # @param attrs [Hash, nil]
      # @param submitted [Hash, nil]
      # @return [Symbol] +:inside+, +:outside+, or +:unknown+
      def prewrite_verdict(record, attrs, submitted)
        parent = tenant_verdict(record, attrs)
        return parent unless parent == :inside

        nested_rows_verdict(record, attrs.nil? ? submitted : attrs)
      end

      # @param record [Object]
      # @param attrs [Hash, nil] +nil+ uses +record+ itself (create)
      # @return [Symbol] +:inside+, +:outside+, or +:unknown+
      def tenant_verdict(record, attrs)
        candidate = attrs.nil? ? record : adapter.preview(record, attrs)
        return :unknown if candidate.nil?

        adapter.scope_match(base_scope, candidate)
      end

      # @param verdict [Symbol] +:outside+ or +:unknown+
      # @return [String]
      def containment_error(verdict)
        key = verdict == :outside ? "outside_tenant" : "tenant_unverifiable"
        I18n.t("iron_admin.resources.errors.#{key}")
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
