# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Http
      # Infers IronAdmin field types from JSON values.
      #
      # Used for auto-discovery: the adapter fetches the first API response
      # and uses this class to determine column types from the JSON data,
      # matching IronAdmin's convention-over-configuration philosophy.
      module TypeInferrer
        ISO8601_DATETIME = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
        ISO8601_DATE = /\A\d{4}-\d{2}-\d{2}\z/

        # Infers the IronAdmin type symbol from a JSON value.
        #
        # @param value [Object] A value from a JSON response
        # @return [Symbol] The inferred field type
        def self.infer(value)
          case value
          when Integer, Float then :number
          when TrueClass, FalseClass then :boolean
          when Hash, Array then :json
          when String then infer_string_type(value)
          else :string
          end
        end

        # Infers column descriptors from a JSON hash (one record).
        #
        # @param data [Hash] A single JSON record
        # @return [Array<ColumnDescriptor>] Inferred column descriptors
        def self.infer_columns(data)
          data.map { |key, value| ColumnDescriptor.new(key.to_s, infer(value)) }
        end

        def self.infer_string_type(value)
          if value.match?(ISO8601_DATETIME)
            :datetime
          elsif value.match?(ISO8601_DATE)
            :date
          else
            :string
          end
        end

        private_class_method :infer_string_type
      end
    end
  end
end
