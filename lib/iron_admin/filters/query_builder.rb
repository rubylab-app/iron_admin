# frozen_string_literal: true

module IronAdmin
  module Filters
    # Builds ActiveRecord query conditions for string and number filter operators.
    #
    # Supports operator-based filtering with safe SQL generation:
    # - String: contains, equals, starts_with, ends_with
    # - Number: equals, greater_than, less_than, between
    #
    # All values are bound via parameterized queries. Operators are validated
    # against a whitelist. Column names are always quoted via the connection.
    #
    # @example
    #   filter = { name: :email, type: :string }
    #   params = { "op" => "contains", "value" => "acme" }
    #   scope = IronAdmin::Filters::QueryBuilder.call(User.all, filter, params)
    class QueryBuilder
      STRING_OPS = %w[contains equals starts_with ends_with].freeze
      NUMBER_OPS = %w[equals greater_than less_than between].freeze

      # Applies the filter to the given scope.
      #
      # @param scope [ActiveRecord::Relation] The base scope
      # @param filter [Hash] Filter definition with :name and :type keys
      # @param params_hash [Hash] User-submitted params with "op", "value", and optional "value_2"
      # @return [ActiveRecord::Relation] The filtered scope
      def self.call(scope, filter, params_hash)
        new(scope, filter, params_hash).call
      end

      def initialize(scope, filter, params_hash)
        @scope = scope
        @filter = filter
        @op = params_hash["op"].to_s
        @value = params_hash["value"].to_s.strip
        @upper_value = params_hash["value_2"].to_s.strip
        @conn = scope.connection
      end

      def call
        return @scope if @value.blank?

        case @filter[:type]
        when :string then apply_string_filter
        when :number then apply_number_filter
        else @scope
        end
      end

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
        table = @conn.quote_table_name(@scope.model.table_name)
        "#{table}.#{@conn.quote_column_name(@filter[:name])}"
      end

      def sanitize_like(value)
        value.gsub(/[%_\\]/) { |m| "\\#{m}" }
      end

      def cast_number(val)
        return nil if val.blank?

        val.include?(".") ? Float(val) : Integer(val)
      rescue ArgumentError, TypeError
        nil
      end

      def postgres?
        @conn.adapter_name.match?(/PostgreSQL/i)
      end
    end
  end
end
