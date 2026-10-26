# frozen_string_literal: true

module IronAdmin
  module Resources
    # Renders a list of related records for has_many associations.
    class RelatedListComponent < ViewComponent::Base
      # @return [Hash] Association configuration
      attr_reader :association

      # @return [ActiveRecord::Relation] Related records
      attr_reader :records

      # @return [Integer] Max records to show
      attr_reader :limit

      # @return [Object, nil] The record that owns the association
      attr_reader :parent

      # @param association [Hash] Association config
      # @param records [ActiveRecord::Relation] Records
      # @param limit [Integer] Max records (default: 20)
      # @param parent [Object, nil] The record that owns the association. With it,
      #   "View all" can narrow the index to that record's related records.
      def initialize(association:, records:, limit: 20, parent: nil)
        @association = association
        @records = records.limit(limit)
        @limit = limit
        @parent = parent
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme configuration
      def theme
        IronAdmin.configuration.theme
      end

      # @api private
      # @return [String] Humanized association title
      def title
        association[:name].to_s.humanize
      end

      # @api private
      # @return [String] Associated resource name
      def resource_name
        association[:resource].resource_name
      end

      # @api private
      # @return [Symbol, Proc, nil] Display method for record labels
      def display_method
        association[:display]
      end

      # @api private
      # The index applies only the filters its resource declares or infers, so
      # the link narrows it to the parent's records only when one covers the
      # foreign key.
      #
      # @return [String] URL to view all records
      def view_all_url
        filters = parent_filters
        return helpers.iron_admin.resources_path(resource_name) unless filters

        helpers.iron_admin.resources_path(resource_name, filters: filters)
      end

      # @api private
      # @param record [ActiveRecord::Base] The record
      # @return [String] URL to view the record
      def record_url(record)
        helpers.iron_admin.resource_path(resource_name, record)
      end

      # @api private
      # @return [Boolean] Whether to render the component
      def render?
        records.any?
      end

      private

      def parent_filters
        key = parent_foreign_key
        filter = key && association[:resource].all_filters.find { |candidate| candidate[:name].to_s == key }
        value = filter && parent_key_value
        return if value.nil?

        case filter[:type]
        when :string, :number then { key => { op: "equals", value: value } }
        when :date_range, :boolean then nil
        else { key => value }
        end
      end

      # Through and polymorphic (as:) associations have no single column that
      # picks out the parent's records.
      def parent_foreign_key
        reflection = association[:reflection]
        return unless parent && reflection
        return if reflection.try(:through_reflection?) || reflection.try(:polymorphic?)
        return if reflection.try(:options).to_h[:as]

        key = reflection.foreign_key
        key.to_s.presence if key.is_a?(String) || key.is_a?(Symbol)
      end

      def parent_key_value
        key = association[:reflection].try(:active_record_primary_key) || :id
        parent.public_send(key) unless key.is_a?(Array)
      end
    end
  end
end
