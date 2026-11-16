# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Stamps tenant equalities onto new nested rows and keeps them off updates.
    module TenantAssignable
      extend ActiveSupport::Concern

      private

      # Copies tenant equalities into new nested rows of the submitted attributes.
      #
      # Returns +attrs+ unchanged unless a tenant scope is configured. Otherwise
      # returns a Hash with string keys. For each nested association whose
      # +"#{name}_attributes"+ entry is present (a Hash of index to row, or an
      # Array of rows), every row without a present +id+ merges
      # +scope_attributes+ of +TenantScope.apply(nested.reflection.klass.all)+,
      # with the tenant values winning.
      #
      # @param attrs [Hash, ActionController::Parameters] permitted attributes
      # @return [Hash, ActionController::Parameters]
      def with_nested_tenant_attributes(attrs)
        return attrs unless IronAdmin::TenantScope.configured?

        stamped = string_keyed_attributes(attrs)
        @resource_class.nested_associations.each do |nested|
          key = "#{nested.name}_attributes"
          next unless stamped.key?(key)

          stamped[key] = stamp_nested_attribute_rows(nested, stamped[key])
        end
        stamped
      end

      # Removes tenant columns from submitted attributes.
      #
      # Keys are compared as strings. Only scalar equalities returned by
      # +scope_attributes+ are protected.
      #
      # @param attrs [Hash, ActionController::Parameters] permitted attributes
      # @return [Hash, ActionController::Parameters]
      def without_tenant_attributes(attrs)
        protected_keys = adapter.scope_attributes(base_scope).keys.map(&:to_s)
        removable = attrs.keys.select { |key| protected_keys.include?(key.to_s) }
        attrs.except(*removable)
      end

      def stamp_nested_attribute_rows(nested, rows)
        tenant = nested_tenant_attributes(nested)
        if rows.is_a?(Array)
          rows.map { |row| merge_tenant_into_new_row(row, tenant) }
        else
          string_keyed_attributes(rows).each_with_object({}) do |(index, row), stamped|
            stamped[index] = merge_tenant_into_new_row(row, tenant)
          end
        end
      end

      def nested_tenant_attributes(nested)
        scope = IronAdmin::TenantScope.apply(nested.reflection.klass.all)
        adapter.scope_attributes(scope)
      end

      def merge_tenant_into_new_row(row, tenant)
        attributes = string_keyed_attributes(row)
        return attributes if attributes["id"].present?

        attributes.merge(tenant)
      end

      def string_keyed_attributes(attrs)
        source = attrs.respond_to?(:to_h) ? attrs.to_h : attrs
        source.each_with_object({}) do |(key, value), copy|
          copy[key.to_s] = value
        end
      end
    end
  end
end
