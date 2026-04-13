# frozen_string_literal: true

module IronAdmin
  module Filters
    # Mongoid-specific query builder for operator-based filters.
    # Uses MongoDB $regex for string ops and comparison operators for number ops.
    class MongoidQueryBuilder < BaseQueryBuilder
      private

      def apply_string_filter
        return @scope unless STRING_OPS.include?(@op)

        case @op
        when "contains"    then @scope.where(@filter[:name] => /#{Regexp.escape(@value)}/i)
        when "equals"      then @scope.where(@filter[:name] => @value)
        when "starts_with" then @scope.where(@filter[:name] => /\A#{Regexp.escape(@value)}/i)
        when "ends_with"   then @scope.where(@filter[:name] => /#{Regexp.escape(@value)}\z/i)
        else @scope
        end
      end

      def apply_number_filter
        return @scope unless NUMBER_OPS.include?(@op)

        num = cast_number(@value)
        return @scope unless num

        case @op
        when "equals"       then @scope.where(@filter[:name] => num)
        when "greater_than" then @scope.where(@filter[:name].gt => num)
        when "less_than"    then @scope.where(@filter[:name].lt => num)
        when "between"      then apply_between_filter(num)
        else @scope
        end
      end

      def apply_between_filter(num)
        upper_num = cast_number(@upper_value)
        return @scope unless upper_num

        @scope.where(@filter[:name].gte => num, @filter[:name].lte => upper_num)
      end
    end
  end
end
