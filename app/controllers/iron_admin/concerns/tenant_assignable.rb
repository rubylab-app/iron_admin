# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Stamps tenant equalities onto new nested rows, strips them from existing
    # rows, and keeps hidden many-to-many ids when updating.
    module TenantAssignable
      extend ActiveSupport::Concern

      private

      # Copies tenant equalities into new nested rows and strips them from saved rows.
      #
      # Returns +attrs+ unchanged unless a tenant scope is configured. Otherwise
      # returns a Hash with string keys. For each nested association whose
      # +"#{name}_attributes"+ entry is present, every row drops the nested
      # model's tenant columns. A +:has_one+ entry is one row of columns. A
      # +:has_many+ entry is a Hash of index to row, or an Array of rows. A row
      # without a present +id+ then merges those tenant values, which win.
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

      # Keeps many-to-many ids that this tenant is not allowed to assign.
      #
      # Update calls this after +references_assignable?+. It first removes a
      # blank polymorphic type and id whose stored type is outside the
      # allowlist, so that pair does not clear the association. When a tenant
      # scope is configured and attrs include +"<singular>_ids"+ for a habtm
      # association, that value becomes the submitted ids plus the record's
      # current ids that +assignable_records+ does not include, as unique
      # strings. A new record has no hidden associations, so create does not
      # call this.
      #
      # @param attrs [Hash, ActionController::Parameters] permitted attributes
      # @return [Hash, ActionController::Parameters]
      def preserve_hidden_habtm_ids(attrs)
        kept = keep_unlisted_polymorphic_targets(@record, attrs)
        return kept unless IronAdmin::TenantScope.configured?

        preserved = string_keyed_attributes(kept)
        replaced = false
        @resource_class.habtm_associations.each do |assoc|
          column = "#{assoc[:name].to_s.singularize}_ids"
          next unless preserved.key?(column)

          preserved[column] = submitted_plus_hidden_ids(assoc, preserved[column])
          replaced = true
        end
        replaced ? preserved : kept
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
        return apply_nested_tenant_row(rows, tenant) if nested.kind == :has_one
        return rows.map { |row| apply_nested_tenant_row(row, tenant) } if rows.is_a?(Array)

        string_keyed_attributes(rows).each_with_object({}) do |(index, row), stamped|
          stamped[index] = apply_nested_tenant_row(row, tenant)
        end
      end

      def nested_tenant_attributes(nested)
        scope = IronAdmin::TenantScope.apply(nested.reflection.klass.all)
        adapter.scope_attributes(scope)
      end

      def apply_nested_tenant_row(row, tenant)
        attributes = string_keyed_attributes(row)
        stripped = attributes.except(*tenant.keys.map(&:to_s))
        return stripped if attributes["id"].present?

        stripped.merge(string_keyed_attributes(tenant))
      end

      def submitted_plus_hidden_ids(assoc, raw_ids)
        klass = assoc[:reflection].klass
        hidden = @record.public_send(assoc[:name]).where.not(
          klass.primary_key => helpers.assignable_records(klass).select(klass.primary_key)
        ).pluck(klass.primary_key)
        (Array(raw_ids) + hidden).map(&:to_s).uniq
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
