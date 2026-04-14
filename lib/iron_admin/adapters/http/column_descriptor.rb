# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Http
      # Value object representing a field descriptor for HTTP resources.
      # Provides .name (String) and .type (Symbol) as expected by FieldInferrer.
      ColumnDescriptor = Struct.new(:name, :type) do
        def to_s
          name
        end
      end
    end
  end
end
