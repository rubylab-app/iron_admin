# frozen_string_literal: true

require_relative "base_query_builder"
require_relative "active_record_query_builder"

module IronAdmin
  module Filters
    # Backward-compatible alias for ActiveRecordQueryBuilder.
    # @deprecated Use {ActiveRecordQueryBuilder} directly.
    QueryBuilder = ActiveRecordQueryBuilder
  end
end
