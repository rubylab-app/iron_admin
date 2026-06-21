# frozen_string_literal: true

require "json"

module IronAdmin
  module Import
    module Parser
      class Json
        def initialize(source)
          @source = source
        end

        def parse
          records = extract_records(::JSON.parse(read_source))
          records.map { |row| row.transform_keys(&:to_s) }
        end

        private

        def extract_records(parsed)
          return parsed if parsed.is_a?(Array)
          return parsed["records"] if parsed.is_a?(Hash) && parsed["records"].is_a?(Array)

          raise ArgumentError, "JSON import must be an array or an object with a records array"
        end

        def read_source
          @source.rewind if @source.respond_to?(:rewind)
          return @source.read if @source.respond_to?(:read)

          File.read(@source.to_s)
        end
      end
    end
  end
end
