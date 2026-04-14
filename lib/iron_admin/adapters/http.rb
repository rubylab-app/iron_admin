# frozen_string_literal: true

module IronAdmin
  module Adapters
    # HTTP REST API adapter — enables IronAdmin to manage resources
    # from external REST APIs with convention-over-configuration.
    #
    # Fields are auto-discovered from the first API response.
    # Faraday is used as the HTTP transport (lazy loaded).
    #
    # @example Minimal resource configuration
    #   class ProductResource < IronAdmin::Resource
    #     self.adapter_class = :http
    #     http_config do |c|
    #       c.base_url = "https://api.example.com/v1"
    #     end
    #   end
    class Http < Base
      # --- Schema Introspection ---

      def columns
        discovered_columns
      end

      def column_names
        discovered_columns.map(&:name)
      end

      def has_column?(name) # rubocop:disable Naming/PredicatePrefix
        column_names.include?(name.to_s)
      end

      def enums
        {}
      end

      def associations(_kind = nil)
        []
      end

      def association(_name)
        nil
      end

      def attachments
        {}
      end

      def rich_text_attributes
        []
      end

      # --- Naming ---

      def table_name
        nil
      end

      # --- Query Building ---

      def all
        Query.new(connection)
      end

      def find(id)
        data = connection.get_one(id.to_s)
        Record.new(data)
      end

      def find_by(attrs)
        all.where(attrs).first
      end

      def filter(scope, column, value)
        scope.where(column => value)
      end

      def order_by(scope, column, direction)
        scope.order(column => direction)
      end

      def limit(scope, max)
        scope.limit(max)
      end

      def preload(scope, _association_names)
        scope
      end

      def distinct_values(column)
        all.pluck(column).compact.uniq.sort_by(&:to_s)
      end

      def pluck(scope, column)
        scope.pluck(column)
      end

      def count(scope = nil)
        (scope || all).count
      end

      # --- Search ---

      def search_column(scope, column, query)
        scope.where("search[#{column}]" => query)
      end

      def search_columns(scope, columns, query)
        scope.where(q: query, search_fields: columns.join(","))
      end

      # --- CRUD ---

      def build(attrs = {})
        Record.new(attrs.merge(_persisted: false))
      end

      def save(record)
        if record.persisted?
          data = connection.patch(record.id.to_s, record.attributes.except("id"))
          return false unless data.is_a?(Hash)
        else
          data = connection.post(record.attributes.except("id"))
          return false unless data.is_a?(Hash) && data["id"]
        end

        record.assign_attributes(data)
        record.mark_as_persisted
        true
      rescue IronAdmin::AdapterError
        false
      end

      def update(record, attrs)
        data = connection.patch(record.id.to_s, attrs)
        return false unless data.is_a?(Hash)

        record.assign_attributes(attrs)
        record.assign_attributes(data)
        record.mark_as_persisted
        true
      rescue IronAdmin::AdapterError
        false
      end

      def destroy!(record)
        connection.delete(record.id.to_s)
      end

      # --- Transactions ---

      def transaction
        yield
      end

      # --- Scope Manipulation ---

      def unscope_column(scope, _column)
        scope
      end

      # --- Batch ---

      def find_each(scope, &)
        scope.each(&)
      end

      # --- Adapter-Agnostic Interface ---

      def record_changes(record)
        record.previous_changes
      end

      def wrap_rollback
        yield
      rescue IronAdmin::Rollback
        nil
      end

      def query_builder_class
        IronAdmin::Filters::HttpQueryBuilder
      end

      def pagy_method
        :pagy
      end

      # Allows injecting a pre-built configuration (for testing or per-resource override).
      attr_writer :http_config

      private

      def connection
        @connection ||= Connection.new(http_config)
      end

      def http_config
        @http_config ||= build_config
      end

      def build_config
        config = Configuration.new
        global = IronAdmin.configuration
        config.base_url = global.respond_to?(:http_base_url) ? global.http_base_url : nil
        config.headers = global.respond_to?(:http_headers) ? global.http_headers : {}
        config.resource_path = "/#{resource_name}"
        config
      end

      def discovered_columns
        @discovered_columns ||= discover_columns
      end

      def discover_columns
        response = connection.get
        return [] if response[:data].empty?

        TypeInferrer.infer_columns(response[:data].first)
      rescue IronAdmin::AdapterError, IronAdmin::RecordNotFound
        []
      end
    end
  end
end

require_relative "http/column_descriptor"
require_relative "http/type_inferrer"
require_relative "http/record"
require_relative "http/configuration"
require_relative "http/connection"
require_relative "http/query"
require_relative "../filters/http_query_builder"
