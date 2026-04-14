# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Http
      # Configuration for an HTTP resource's API connection.
      #
      # Stores base URL, resource path, and headers.
      # Each HTTP resource can override the global configuration.
      class Configuration
        attr_accessor :base_url, :resource_path, :headers

        def initialize
          @base_url = nil
          @resource_path = nil
          @headers = {}
        end

        def full_url
          base = @base_url&.chomp("/") || ""
          path = @resource_path&.start_with?("/") ? @resource_path : "/#{@resource_path}"
          "#{base}#{path}"
        end
      end
    end
  end
end
