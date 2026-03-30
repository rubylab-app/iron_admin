# frozen_string_literal: true

module IronAdmin
  # Controller for global search across all resources.
  #
  # Searches all registered resources and returns matching records.
  class SearchController < ApplicationController
    # Renders global search results.
    # @return [void]
    def index
      @query = params[:q].to_s.strip
      @results = search_all_resources if @query.present?
    end

    private

    def search_all_resources
      ResourceRegistry.all.filter_map do |resource_class|
        columns = resource_class.searchable_columns
        next if columns.empty?

        resource_adapter = resource_class.adapter
        records = resource_adapter.search_columns(resource_adapter.all, columns, @query)
        records = resource_adapter.limit(records, 5)

        next if records.empty?

        { resource: resource_class, records: records }
      end
    end
  end
end
