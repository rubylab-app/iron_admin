# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Provides nested attribute strong parameter building for resource controllers.
    module NestedPermittable
      extend ActiveSupport::Concern

      private

      # Builds the permit list for a nested association's attributes.
      #
      # Includes all non-readonly field names, :id for matching existing records,
      # :_destroy when allow_destroy is true, and the position_field when present.
      #
      # @param nested [IronAdmin::NestedAssociation]
      # @return [Array] Permit list for strong params
      def build_nested_permit_list(nested)
        nested_fields = nested.fields.reject { |f| f.readonly?(iron_admin_current_user) }
        permit_list = nested_fields.flat_map { |f| nested_field_permit(f) }
        permit_list << :id
        permit_list << :_destroy if nested.allow_destroy
        permit_list << nested.position_field if nested.position_field
        permit_list
      end

      def nested_field_permit(field)
        case field.type
        when :belongs_to then field.options[:foreign_key]
        when :files then { field.name => [] }
        else field.name
        end
      end
    end
  end
end
