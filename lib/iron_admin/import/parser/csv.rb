# frozen_string_literal: true

require "csv"

module IronAdmin
  module Import
    module Parser
      class Csv
        def initialize(source, encoding: "UTF-8")
          @source = source
          @encoding = encoding
        end

        def parse
          ::CSV.parse(read_source, headers: true, encoding: @encoding).filter_map do |row|
            hash = row.to_h
            next if hash.values.all? { |value| value.to_s.strip.blank? }

            hash
          end
        end

        private

        def read_source
          @source.rewind if @source.respond_to?(:rewind)
          return @source.read if @source.respond_to?(:read)

          File.read(@source.to_s)
        end
      end
    end
  end
end
