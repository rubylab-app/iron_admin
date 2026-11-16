# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Tenant-scope checks for posted polymorphic belongs_to references.
    module PolymorphicReferences
      extend ActiveSupport::Concern

      private

      def polymorphic_references_assignable?(record, attrs)
        polymorphic_fields.map { |field| polymorphic_field_assignable?(record, attrs, field) }.all?
      end

      def polymorphic_fields
        writable_form_fields.select { |field| field.type == :polymorphic_belongs_to }
      end

      def polymorphic_field_assignable?(record, attrs, field)
        return true unless polymorphic_column_submitted?(attrs, field)

        target_id = polymorphic_target_id(record, attrs, field)
        return true if target_id.blank? || polymorphic_target_assignable?(record, attrs, field, target_id)

        record.errors.add(field.name, message: not_assignable_message)
        false
      end

      def polymorphic_column_submitted?(attrs, field)
        return false unless attrs.is_a?(Hash)

        type_column = field.options[:type_column].to_s
        id_column = field.options[:id_column].to_s
        attrs.key?(type_column) || attrs.key?(id_column)
      end

      def polymorphic_target_assignable?(record, attrs, field, target_id)
        type_class = polymorphic_type_class(record, attrs, field)
        return false unless type_class

        helpers.assignable_records(type_class).exists?(id: target_id)
      end

      def polymorphic_target_id(record, attrs, field)
        column = field.options[:id_column].to_s
        # Blank is a submitted clear; fall back only when the key was omitted.
        return attrs[column] if attrs.key?(column)

        record.public_send(field.options[:id_column])
      end

      def polymorphic_type_class(record, attrs, field)
        type_name = polymorphic_type_name(record, attrs, field).to_s
        Array(field.options[:types]).find { |type| type.name.to_s == type_name }
      end

      def polymorphic_type_name(record, attrs, field)
        column = field.options[:type_column].to_s
        return attrs[column] if attrs.key?(column)

        record.public_send(field.options[:type_column])
      end
    end
  end
end
