# frozen_string_literal: true

require "active_model/naming"

module IronAdmin
  module Adapters
    class Http < Base
      # Lightweight stand-in for a Ruby model class when a Resource uses
      # the HTTP adapter. The HTTP adapter pulls fields from the remote
      # API at request time, so there's no Ruby model to introspect — but
      # `Resource.adapter` still needs an object that responds to the
      # minimal `ActiveModel::Naming` interface (`.model_name.plural`,
      # `.model_name.human`) so URLs and labels work.
      #
      # The proxy is built from the resource class name:
      # `IronAdmin::Resources::ExternalCustomerResource` →
      # `model_name.plural = "external_customers"`,
      # `model_name.human = "External customer"`.
      #
      # @example
      #   IronAdmin::Adapters::Http::ModelProxy.new(MyResource).model_name.plural
      #   #=> "my_resources"
      class ModelProxy
        # @return [Class] The Resource class this proxy stands in for.
        attr_reader :resource_class

        # @param resource_class [Class] The IronAdmin::Resource subclass.
        def initialize(resource_class)
          @resource_class = resource_class
        end

        # ActiveModel::Naming-compatible name object derived from the
        # resource class name.
        #
        # @return [ActiveModel::Name]
        def model_name
          @model_name ||= ActiveModel::Name.new(self, nil, demodulized_name)
        end

        # HTTP resources have no Ruby-side schema; columns are discovered
        # from the first API response. Return an empty list so any
        # column-introspection checks (e.g. soft-delete detection) decide
        # the column is absent rather than crashing.
        #
        # @return [Array<String>]
        def column_names
          []
        end

        # Mirror `Class#name` so anything logging the model class doesn't
        # show `#<Adapters::Http::ModelProxy:0x...>`.
        #
        # @return [String]
        def name
          demodulized_name
        end

        alias to_s name

        private

        # Strips `IronAdmin::Resources::` and the trailing `Resource`
        # suffix to mirror what `Resource.model` would return for an
        # ActiveRecord-backed resource (e.g. `ExternalCustomer`).
        #
        # @return [String]
        def demodulized_name
          @demodulized_name ||= resource_class.name
            .sub(/\AIronAdmin::Resources::/, "")
            .sub(/Resource\z/, "")
        end
      end
    end
  end
end
