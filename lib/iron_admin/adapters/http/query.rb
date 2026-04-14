# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Http
      # Chainable lazy query object for HTTP API resources.
      #
      # Accumulates filters, ordering, limit, and offset as parameters.
      # Only fires an HTTP request when records are actually needed
      # (via #each, #count, #first, #map, etc.).
      #
      # Implements the interface that IronAdmin controllers and Pagy expect:
      # .count, .offset(n), .limit(n), .first, .map, .each, .merge
      class Query
        include Enumerable

        def initialize(connection, params: {}, offset_value: nil, limit_value: nil, sort_params: {})
          @connection = connection
          @params = params.dup
          @offset_value = offset_value
          @limit_value = limit_value
          @sort_params = sort_params.dup
          @fetched = false
          @records = nil
          @total = nil
        end

        def each(&block)
          return to_enum(:each) unless block

          fetch!
          @records.each(&block)
        end

        def count
          fetch!
          @total || @records.length
        end

        def first
          fetch!
          @records.first
        end

        def empty?
          fetch!
          @records.empty?
        end

        def where(conditions = {})
          dup_with(params: @params.merge(conditions))
        end

        def offset(value)
          dup_with(offset_value: value)
        end

        def limit(value)
          dup_with(limit_value: value)
        end

        def order(sort_hash)
          dup_with(sort_params: @sort_params.merge(sort_hash))
        end

        def merge(other)
          return dup_with unless other.is_a?(Query)

          dup_with(params: @params.merge(other.accumulated_params))
        end

        protected

        def accumulated_params
          @params
        end

        private

        def dup_with(params: @params, offset_value: @offset_value, limit_value: @limit_value,
                     sort_params: @sort_params)
          self.class.new(
            @connection,
            params: params,
            offset_value: offset_value,
            limit_value: limit_value,
            sort_params: sort_params
          )
        end

        def fetch!
          return if @fetched

          request_params = build_request_params
          response = @connection.get(params: request_params)
          @records = response[:data].map { |attrs| Record.new(attrs) }
          @total = response[:total]
          @fetched = true
        end

        def build_request_params
          result = @params.dup
          result[:offset] = @offset_value if @offset_value
          result[:limit] = @limit_value if @limit_value
          result[:sort] = @sort_params.map { |col, dir| "#{col}:#{dir}" }.join(",") if @sort_params.any?
          result
        end
      end
    end
  end
end
