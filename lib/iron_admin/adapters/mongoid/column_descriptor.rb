# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Mongoid
      # Uses the shared ColumnDescriptor from Adapters::Base.
      ColumnDescriptor = IronAdmin::Adapters::Base::ColumnDescriptor
    end
  end
end
