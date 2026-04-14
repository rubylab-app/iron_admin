# frozen_string_literal: true

module IronAdmin
  module Adapters
    # Lazily loads and resolves adapter classes by identifier.
    #
    # Adapters are loaded on demand to avoid requiring unnecessary ORM
    # dependencies. ActiveRecord apps never load Mongoid code and vice versa.
    #
    # @example Resolving an adapter
    #   IronAdmin::Adapters::Registry.resolve(:active_record)
    #   #=> IronAdmin::Adapters::ActiveRecord
    #
    # @example Using a custom adapter (pass the class directly to adapter_class)
    #   self.adapter_class = MyGem::IronAdminAdapter
    module Registry
      ADAPTERS = {
        active_record: {
          require_path: "iron_admin/adapters/active_record",
          class_name: "IronAdmin::Adapters::ActiveRecord",
        },
        mongoid: {
          require_path: "iron_admin/adapters/mongoid",
          class_name: "IronAdmin::Adapters::Mongoid",
        },
        http: {
          require_path: "iron_admin/adapters/http",
          class_name: "IronAdmin::Adapters::Http",
        },
      }.freeze

      # Resolves an adapter identifier to its class.
      #
      # @param identifier [Symbol] The adapter identifier (e.g., :active_record, :mongoid)
      # @return [Class] The adapter class
      # @raise [ArgumentError] If the identifier is not registered
      def self.resolve(identifier)
        entry = ADAPTERS.fetch(identifier) { raise ArgumentError, "Unknown adapter: #{identifier}" }
        require entry[:require_path]
        entry[:class_name].constantize
      end
    end
  end
end
