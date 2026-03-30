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
      # @param scope [ActiveRecord::Relation] Base scope
      # @return [ActiveRecord::Relation] Filtered scope
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
        sub = params.dig(:filters, filter[:name].to_s)
        return scope unless sub.is_a?(ActionController::Parameters) && sub["value"].present?

        IronAdmin::Filters::QueryBuilder.call(scope, filter, sub.to_unsafe_h)
      end

      def apply_date_range_filter(scope, filter)
        from = params.dig(:filters, "#{filter[:name]}_from")
        to = params.dig(:filters, "#{filter[:name]}_to")
        scope = scope.where(filter[:name] => parse_date(from)..) if from.present? && parse_date(from)
        scope = scope.where(filter[:name] => ..parse_date(to)&.end_of_day) if to.present? && parse_date(to)
        scope
      end

      def apply_flat_filter(scope, filter)
        value = params.dig(:filters, filter[:name])
        return scope if value.blank?
        return scope unless value.is_a?(String)

        value = ActiveModel::Type::Boolean.new.cast(value) if filter[:type] == :boolean

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
