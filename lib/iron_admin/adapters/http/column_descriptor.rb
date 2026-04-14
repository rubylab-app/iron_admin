# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Http
      # Uses the shared ColumnDescriptor from Adapters::Base.
      ColumnDescriptor = IronAdmin::Adapters::Base::ColumnDescriptor
    end
  end
end
