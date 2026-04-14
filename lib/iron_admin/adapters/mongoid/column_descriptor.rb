# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Mongoid
      # Value object mimicking AR's column interface for Mongoid fields.
      # Provides .name (String) and .type (Symbol) as expected by FieldInferrer.
      ColumnDescriptor = Struct.new(:name, :type) do
        def to_s
          name
        end
      end
    end
  end
end
