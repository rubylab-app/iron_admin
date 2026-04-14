# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Http
      # Configuration for an HTTP resource's API connection.
      #
      # Stores base URL, resource path, headers, and pagination settings.
      # Each HTTP resource can override the global configuration.
      class Configuration
        attr_accessor :base_url, :resource_path, :headers, :pagination_style, :response_format

        def initialize
          @base_url = nil
          @resource_path = nil
          @headers = {}
          @pagination_style = :none
          @response_format = :json
        end

        def full_url
          "#{@base_url}#{@resource_path}"
        end
      end
    end
  end
end
