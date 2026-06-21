# frozen_string_literal: true

module IronAdmin
  module Resources
    # Renders the main data table for resource index pages.
    class DataTableComponent < ViewComponent::Base
      renders_one :empty_state

      # @return [ActiveRecord::Relation] Records to display
      attr_reader :records

      # @return [Array<IronAdmin::Field>] Fields to show as columns
      attr_reader :fields

      # @return [Class] The resource class
      attr_reader :resource_class

      # @return [Symbol, nil] Current sort column
      attr_reader :current_sort

      # @return [Symbol, nil] Current sort direction
      attr_reader :current_direction

      # @return [String] Base URL for sorting links
      attr_reader :base_url

      # @return [Object, nil] Current user
      attr_reader :current_user

      # @param records [ActiveRecord::Relation] Records
      # @param fields [Array<IronAdmin::Field>] Fields
      # @param resource_class [Class] Resource class
      # @param base_url [String] Base URL
      # @param current_sort [Symbol, nil] Sort column
      def initialize(records:, fields:, resource_class:, base_url:, current_sort: nil,
                     current_direction: nil, current_user: nil)
        @records = records
        @fields = fields
        @resource_class = resource_class
        @current_sort = current_sort
        @current_direction = current_direction
        @base_url = base_url
        @current_user = current_user
      end

      # @api private
      # @return [Array<IronAdmin::Field>] Fields visible to current user
      def visible_fields
        @visible_fields ||= @fields.select { |f| f.visible?(@current_user) }
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme configuration
      def theme
        IronAdmin.configuration.theme
      end

      # @api private
      # @return [String] CSS classes for table element
      def table_classes
        "min-w-full divide-y #{theme.card_bg} #{theme.border_radius} #{theme.card_shadow}"
      end

      # @api private
      # @return [String] CSS classes for table header
      def header_classes
        theme.table_header_bg
      end

      delegate :empty?, to: :records

      # @api private
      # @param field_name [Symbol, String] Field name to sort by
      # @return [String] URL with sort parameters
      def sort_url(field_name)
        direction = current_sort == field_name.to_s && current_direction == "asc" ? "desc" : "asc"
        "#{base_url}&sort=#{field_name}&direction=#{direction}"
      end

      # @api private
      # @param field_name [Symbol, String] Field name to check
      # @return [Boolean] Whether this field is currently sorted
      def sorted?(field_name)
        current_sort == field_name.to_s
      end

      # @api private
      # @return [String, nil] Current sort direction
      def sort_direction
        current_direction
      end

      # @api private
      # @return [String] Stable Turbo Stream target id for a record row
      def row_dom_id(record)
        "iron_admin_#{resource_class.resource_name}_row_#{record.id}"
      end
    end
  end
end
