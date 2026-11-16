# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Rejects posted foreign keys that are outside the tenant-scoped options.
    module AssignableReferences
      extend ActiveSupport::Concern
      include PolymorphicReferences

      private

      # Whether every posted reference points at a tenant-assignable record.
      #
      # Returns true immediately when no tenant scope is configured, without
      # querying. Only keys present in +attrs+ are checked. Each rejected
      # reference adds an error on +record+ and makes this method return false.
      #
      # @param record [ActiveRecord::Base] record about to be saved
      # @param attrs [ActionController::Parameters, Hash] permitted attributes
      # @return [Boolean] true when this check added no error
      def references_assignable?(record, attrs)
        return true unless IronAdmin::TenantScope.configured?

        reference_checks_pass?(record, deep_stringify(unwrap_params(attrs)))
      end

      def reference_checks_pass?(record, attrs)
        [
          belongs_to_references_assignable?(record, attrs),
          polymorphic_references_assignable?(record, attrs),
          habtm_references_assignable?(record, attrs),
          nested_references_assignable?(record, attrs),
        ].all?
      end

      def belongs_to_references_assignable?(record, attrs)
        belongs_to_fields.map { |field| belongs_to_field_assignable?(record, attrs, field) }.all?
      end

      def belongs_to_fields
        writable_form_fields.select { |field| field.type == :belongs_to }
      end

      def belongs_to_field_assignable?(record, attrs, field)
        return true if foreign_key_assignable?(attrs, field, @resource_class.model)

        record.errors.add(field.name, message: not_assignable_message)
        false
      end

      def habtm_references_assignable?(record, attrs)
        @resource_class.habtm_associations.map { |assoc| habtm_association_assignable?(record, attrs, assoc) }.all?
      end

      def habtm_association_assignable?(record, attrs, assoc)
        column = "#{assoc[:name].to_s.singularize}_ids"
        return true unless attrs.key?(column)
        return true if habtm_ids_assignable?(assoc, attrs[column])

        record.errors.add(assoc[:name], message: not_assignable_message)
        false
      end

      def habtm_ids_assignable?(assoc, raw_ids)
        ids = Array(raw_ids).compact_blank.uniq
        return true if ids.empty?

        klass = assoc[:reflection].klass
        helpers.assignable_records(klass).where(klass.primary_key => ids).count == ids.size
      end

      def nested_references_assignable?(record, attrs)
        @resource_class.nested_associations.map { |nested| nested_association_assignable?(record, attrs, nested) }.all?
      end

      def nested_association_assignable?(record, attrs, nested)
        column = "#{nested.name}_attributes"
        return true unless attrs.key?(column)

        nested_child_rows(nested, attrs[column]).map { |child| nested_child_assignable?(record, nested, child) }.all?
      end

      def nested_child_rows(nested, raw)
        rows = nested.kind == :has_one ? [raw] : indexed_or_array_rows(raw)
        rows.grep(Hash)
      end

      def indexed_or_array_rows(raw)
        raw.is_a?(Hash) ? raw.values : Array(raw)
      end

      def nested_child_assignable?(record, nested, child)
        nested_belongs_to_fields(nested).map { |field| nested_field_assignable?(record, nested, child, field) }.all?
      end

      def nested_belongs_to_fields(nested)
        Array(nested.fields).select { |field| field.type == :belongs_to }
      end

      def nested_field_assignable?(record, nested, child, field)
        return true if foreign_key_assignable?(child, field, nested.reflection.klass)

        record.errors.add(:base, message: nested_not_assignable_message(nested))
        false
      end

      def foreign_key_assignable?(attrs, field, owner_class)
        column = field.options[:foreign_key].to_s
        return true unless present_attr?(attrs, column)

        value_key = helpers.association_value_key(owner_class, field.options[:association_name])
        helpers.assignable_records(field.options[:association_class]).exists?(value_key => attrs[column])
      end

      def present_attr?(attrs, column)
        key = column.to_s
        attrs.is_a?(Hash) && attrs.key?(key) && attrs[key].present?
      end

      def not_assignable_message
        I18n.t("iron_admin.resources.errors.not_assignable")
      end

      def nested_not_assignable_message(nested)
        I18n.t(
          "iron_admin.resources.errors.nested_not_assignable",
          association: nested.name.to_s.humanize
        )
      end

      def unwrap_params(value)
        return value.to_unsafe_h if value.respond_to?(:to_unsafe_h)

        value.is_a?(ActionController::Parameters) ? value.to_h : value
      end

      def deep_stringify(value)
        case value
        when Hash
          value.to_h { |key, nested| [key.to_s, deep_stringify(unwrap_params(nested))] }
        when Array
          value.map { |nested| deep_stringify(unwrap_params(nested)) }
        else
          value
        end
      end
    end
  end
end
