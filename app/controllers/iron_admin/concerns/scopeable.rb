# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Provides scope building and record finding methods for controllers.
    # Extracts base_scope, record_scope, and find_record to keep controllers slim.
    module Scopeable
      extend ActiveSupport::Concern

      private

      def base_scope
        scope = adapter.all
        scope = IronAdmin.configuration.tenant_scope_block.call(scope) if IronAdmin.configuration.tenant_scope_block
        scope
      end

      def record_scope
        scope = base_scope
        scope = adapter.unscope_column(scope, @resource_class.soft_delete_column) if @resource_class.soft_delete?
        scope
      end

      def find_record(scope, id)
        pk = adapter.primary_key

        result = if pk.is_a?(Array)
                   ids = id.to_s.split("_")
                   raise IronAdmin::RecordNotFound if ids.size != pk.size

                   scope.find_by(pk.zip(ids).to_h)
                 else
                   adapter.filter(scope, pk.to_sym, id).first
                 end

        raise IronAdmin::RecordNotFound unless result

        result
      end
    end
  end
end
