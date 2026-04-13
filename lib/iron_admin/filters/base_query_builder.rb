# frozen_string_literal: true

module IronAdmin
  module Filters
    # Abstract base class for operator-based filter query builders.
    #
    # Subclasses implement the adapter-specific query building for string
    # and number filter operators. ActiveRecord uses SQL LIKE/ILIKE,
    # Mongoid uses $regex and comparison operators.
    class BaseQueryBuilder
      STRING_OPS = %w[contains equals starts_with ends_with].freeze
      NUMBER_OPS = %w[equals greater_than less_than between].freeze

      def self.call(scope, filter, params_hash)
        new(scope, filter, params_hash).call
      end

      def initialize(scope, filter, params_hash)
        @scope = scope
        @filter = filter
        @op = params_hash["op"].to_s
        @value = params_hash["value"].to_s.strip
        @upper_value = params_hash["value_2"].to_s.strip
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
        raise NotImplementedError
      end

      def apply_number_filter
        raise NotImplementedError
      end

      def cast_number(val)
        return nil if val.blank?

        val.include?(".") ? Float(val) : Integer(val)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
