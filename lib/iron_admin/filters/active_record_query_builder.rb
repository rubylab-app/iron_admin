# frozen_string_literal: true

module IronAdmin
  module Filters
    # ActiveRecord-specific query builder for operator-based filters.
    # Uses SQL LIKE/ILIKE for string ops and parameterized queries for number ops.
    ActiveRecordQueryBuilder = QueryBuilder
  end
end
