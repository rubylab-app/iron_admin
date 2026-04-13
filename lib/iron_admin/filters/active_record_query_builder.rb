# frozen_string_literal: true

module IronAdmin
  module Filters
    # ActiveRecord-specific query builder for operator-based filters.
    # Uses SQL LIKE/ILIKE for string ops and parameterized queries for number ops.
    class ActiveRecordQueryBuilder < BaseQueryBuilder
      private

      def apply_string_filter
        return @scope unless STRING_OPS.include?(@op)

        col = quoted_column
        like_op = postgres? ? "ILIKE" : "LIKE"
        escape = "ESCAPE '\\'"

        case @op
        when "contains"    then @scope.where("#{col} #{like_op} ? #{escape}", "%#{sanitize_like(@value)}%")
        when "equals"      then @scope.where(@filter[:name] => @value)
        when "starts_with" then @scope.where("#{col} #{like_op} ? #{escape}", "#{sanitize_like(@value)}%")
        when "ends_with"   then @scope.where("#{col} #{like_op} ? #{escape}", "%#{sanitize_like(@value)}")
        else @scope
        end
      end

      def apply_number_filter
        return @scope unless NUMBER_OPS.include?(@op)

        num = cast_number(@value)
        return @scope unless num

        case @op
        when "equals"       then @scope.where(@filter[:name] => num)
        when "greater_than" then @scope.where("#{quoted_column} > ?", num)
        when "less_than"    then @scope.where("#{quoted_column} < ?", num)
        when "between"      then apply_between_filter(num)
        else @scope
        end
      end

      def apply_between_filter(num)
        upper_num = cast_number(@upper_value)
        return @scope unless upper_num

        @scope.where(@filter[:name] => num..upper_num)
      end

      def quoted_column
        conn = @scope.connection
        table = conn.quote_table_name(@scope.model.table_name)
        "#{table}.#{conn.quote_column_name(@filter[:name])}"
      end

      def sanitize_like(value)
        value.gsub(/[%_\\]/) { |m| "\\#{m}" }
      end

      def postgres?
        @scope.connection.adapter_name.match?(/PostgreSQL/i)
      end
    end
  end
end
