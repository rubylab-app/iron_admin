# frozen_string_literal: true

module IronAdmin
  module Filters
    # HTTP-specific query builder for operator-based filters.
    # Translates string and number operators to query parameters
    # that are sent to the remote API.
    class HttpQueryBuilder < BaseQueryBuilder
      private

      def apply_string_filter
        return @scope unless STRING_OPS.include?(@op)

        field = @filter[:name].to_s
        @scope.where("#{field}[#{@op}]" => @value)
      end

      def apply_number_filter
        return @scope unless NUMBER_OPS.include?(@op)

        num = cast_number(@value)
        return @scope unless num

        field = @filter[:name].to_s
        case @op
        when "between" then apply_between_filter(field, num)
        else @scope.where("#{field}[#{@op}]" => num)
        end
      end

      def apply_between_filter(field, num)
        upper_num = cast_number(@upper_value)
        return @scope unless upper_num

        @scope.where("#{field}[gte]" => num, "#{field}[lte]" => upper_num)
      end
    end
  end
end
