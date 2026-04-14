# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Http
      # Wraps Faraday for HTTP communication with REST APIs.
      #
      # Handles request building, response parsing, auth headers,
      # and error mapping to IronAdmin exceptions.
      class Connection
        def initialize(config)
          @config = config
          @base_url = config.full_url
        end

        def get(params: {})
          response = safe_request { faraday.get(@base_url, params) }
          handle_errors(response)
          parse_collection(response)
        end

        def get_one(id)
          response = safe_request { faraday.get("#{@base_url}/#{id}") }
          handle_errors(response)
          parse_json(response.body)
        end

        def post(attrs)
          response = safe_request do
            faraday.post(@base_url) do |req|
              req.headers["Content-Type"] = "application/json"
              req.body = attrs.to_json
            end
          end
          handle_errors(response)
          parse_json(response.body)
        end

        def patch(id, attrs)
          response = safe_request do
            faraday.patch("#{@base_url}/#{id}") do |req|
              req.headers["Content-Type"] = "application/json"
              req.body = attrs.to_json
            end
          end
          handle_errors(response)
          parse_json(response.body)
        end

        def delete(id)
          response = safe_request { faraday.delete("#{@base_url}/#{id}") }
          handle_errors(response)
        end

        private

        def faraday
          @faraday ||= begin
            require "faraday"
            Faraday.new do |conn|
              @config.headers.each { |key, value| conn.headers[key] = value }
              conn.adapter Faraday.default_adapter
            end
          rescue LoadError
            raise IronAdmin::AdapterError,
                  "Faraday is required for the HTTP adapter. Add `gem 'faraday'` to your Gemfile."
          end
        end

        def safe_request
          yield
        rescue Faraday::Error => e
          raise IronAdmin::AdapterError, "HTTP request failed: #{e.message}"
        end

        def handle_errors(response)
          case response.status
          when 200..299, 422 then nil # 422 validation errors handled by caller
          when 404 then raise IronAdmin::RecordNotFound, "Record not found (HTTP 404)"
          else raise IronAdmin::AdapterError, "HTTP #{response.status}: #{response.body}"
          end
        end

        def parse_collection(response)
          body = parse_json(response.body)

          case body
          when Array
            { data: body, total: nil }
          when Hash
            data = body["data"] || body
            total = body.dig("meta", "total")
            { data: data.is_a?(Array) ? data : [data], total: total }
          else
            { data: [], total: nil }
          end
        end

        def parse_json(body)
          return {} if body.blank?

          JSON.parse(body)
        rescue JSON::ParserError
          {}
        end
      end
    end
  end
end
