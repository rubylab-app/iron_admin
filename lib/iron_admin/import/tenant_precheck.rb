# frozen_string_literal: true

module IronAdmin
  module Import
    # In-memory tenant check used when an import adapter cannot roll back.
    module TenantPrecheck
      private

      # Error for a non-transactional adapter when the row is not proven in-tenant.
      #
      # Returns +nil+ when the row may be written: the adapter can roll back,
      # no tenant scope is configured, or {#import_candidate_verdict} is +true+.
      #
      # @param record [Object, nil]
      # @param attributes [Hash]
      # @return [String, nil]
      def unverified_import_message(record, attributes)
        return nil if adapter.supports_transactions?
        return nil unless IronAdmin::TenantScope.configured?

        verdict = import_candidate_verdict(record, attributes)
        return nil if verdict == true

        I18n.t(import_tenant_error_key(verdict))
      end

      # Translates {IronAdmin::Adapters::Base#scope_match} for existing import callers.
      #
      # @param record [Object, nil]
      # @param attributes [Hash]
      # @return [Boolean, nil] +true+ for +:inside+, +false+ for +:outside+, +nil+ for +:unknown+
      def import_candidate_verdict(record, attributes)
        scope = IronAdmin::TenantScope.apply(adapter.all)
        candidate = import_candidate(record, attributes, scope)
        return nil if candidate.nil?

        case adapter.scope_match(scope, candidate)
        when :inside then true
        when :outside then false
        end
      end

      # Candidate from the attributes {#persist_row} will write.
      #
      # An update is previewed with tenant columns removed, the same hash
      # validation and +update_record+ use. A create is built from the row
      # attributes +build_in+ receives.
      #
      # @param record [Object, nil]
      # @param attributes [Hash]
      # @param scope [Object]
      # @return [Object, nil]
      def import_candidate(record, attributes, scope)
        return adapter.preview(record, attributes_without_tenant(attributes)) if record

        adapter.build_in(scope, attributes)
      end

      # @param verdict [Boolean, nil]
      # @return [String]
      def import_tenant_error_key(verdict)
        name = verdict.nil? ? "tenant_unverifiable" : "outside_tenant"
        "iron_admin.imports.errors.#{name}"
      end
    end
  end
end
