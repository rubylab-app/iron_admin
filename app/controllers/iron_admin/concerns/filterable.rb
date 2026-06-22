# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Provides filter functionality for resource controllers.
    #
    # Supports flat filters (:select, :boolean), date range filters,
    # and operator-based filters (:string, :number) via QueryBuilder.
    module Filterable
      extend ActiveSupport::Concern

      private

      # Applies all configured filters to the scope.
      #
      # @param scope [Object] Base query scope (ActiveRecord::Relation or Mongoid::Criteria)
      # @return [Object] Filtered scope
      def apply_filters(scope)
        @resource_class.all_filters.each do |filter|
          scope = case filter[:type]
                  when :string, :number then apply_operator_filter(scope, filter)
                  when :date_range then apply_date_range_filter(scope, filter)
                  else apply_flat_filter(scope, filter)
                  end
        end
        scope
      end

      def apply_operator_filter(scope, filter)
        sub = iron_admin_filter_param(filter[:name].to_s)
        return scope unless sub.is_a?(ActionController::Parameters) && sub["value"].present?

        adapter.query_builder_class.call(scope, filter, sub.to_unsafe_h)
      end

      def apply_date_range_filter(scope, filter)
        from = iron_admin_filter_param("#{filter[:name]}_from")
        to = iron_admin_filter_param("#{filter[:name]}_to")
        scope = adapter.filter(scope, filter[:name], parse_date(from)..) if from.present? && parse_date(from)
        scope = adapter.filter(scope, filter[:name], ..parse_date(to)&.end_of_day) if to.present? && parse_date(to)
        scope
      end

      def apply_flat_filter(scope, filter)
        value = iron_admin_filter_param(filter[:name])
        return scope if value.blank?
        return scope unless value.is_a?(String)

        value = adapter.cast_boolean(value) if filter[:type] == :boolean

        if filter[:scope]
          filter[:scope].call(value, scope)
        else
          adapter.filter(scope, filter[:name], value)
        end
      end

      def parse_date(value)
        return nil if value.blank?

        Date.parse(value)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
