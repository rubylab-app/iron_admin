# frozen_string_literal: true

module IronAdmin
  module Adapters
    # HTTP REST API adapter — enables IronAdmin to manage resources
    # from external REST APIs.
    #
    # Uses convention-over-configuration: fields are auto-discovered
    # from the first API response. Faraday is used as the HTTP transport.
    #
    # @example Minimal resource configuration
    #   class ProductResource < IronAdmin::Resource
    #     self.adapter_class = :http
    #     http_config do |c|
    #       c.base_url = "https://api.example.com/v1"
    #     end
    #   end
    class Http < Base
    end
  end
end

require_relative "http/column_descriptor"
require_relative "http/type_inferrer"
require_relative "http/record"
require_relative "http/configuration"
require_relative "http/connection"
require_relative "http/query"
