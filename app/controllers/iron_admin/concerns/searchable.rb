# frozen_string_literal: true

module IronAdmin
  # Controller concerns for shared functionality.
  module Concerns
    # Provides search functionality for resource controllers.
    #
    # Supports both general search across all searchable columns
    # and field-specific search using "field:value" syntax.
    module Searchable
      extend ActiveSupport::Concern

      private

      # Applies search query to the scope.
      #
      # @param scope [ActiveRecord::Relation] Base scope
      # @return [ActiveRecord::Relation] Filtered scope
      def apply_search(scope)
        query = params[:q].to_s.strip
        return scope if query.blank?

        if query.match?(/^\w+:.+$/)
          field, value = query.split(":", 2)
          return apply_field_search(scope, field, value)
        end

        apply_general_search(scope, query)
      end

      def apply_field_search(scope, field, value)
        return scope unless adapter.has_column?(field)
        return scope unless field_visible?(field.to_sym)

        if value.include?("..") && range_search_column?(field)
          from_str, to_str = value.split("..", 2)
          from_date = parse_date(from_str)
          to_date = parse_date(to_str)

          return adapter.filter(scope, field, from_date..to_date) if from_date && to_date
          return adapter.filter(scope, field, from_date..) if from_date
          return adapter.filter(scope, field, ..to_date) if to_date

          return scope
        end

        adapter.search_column(scope, field, value)
      end

      def range_search_column?(field)
        adapter.columns.any? do |column|
          column.name.to_s == field.to_s && column.type.in?(%i[date datetime])
        end
      end

      def apply_general_search(scope, query)
        columns = visible_searchable_columns
        return scope if columns.empty?

        adapter.search_columns(scope, columns, query)
      end

      def visible_searchable_columns
        visible_names = visible_field_names
        @resource_class.searchable_columns.select { |col| visible_names.include?(col) }
      end

      def field_visible?(field_name)
        visible_field_names.include?(field_name)
      end

      def visible_field_names
        @visible_field_names ||= @resource_class.resolved_fields
          .select { |f| f.visible?(iron_admin_current_user) }
          .map(&:name)
      end
    end
  end
end
