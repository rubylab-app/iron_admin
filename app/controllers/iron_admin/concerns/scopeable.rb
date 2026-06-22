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

      def collection_scope
        scope = apply_scopes(apply_filters(base_scope))
        scope = apply_search(scope)
        scope = apply_sorting(scope)
        apply_preloading(scope)
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

                   pk.zip(ids).reduce(scope) { |s, (col, val)| adapter.filter(s, col.to_sym, val) }.first
                 else
                   adapter.filter(scope, pk.to_sym, id).first
                 end

        raise IronAdmin::RecordNotFound unless result

        result
      end

      def current_scope_name
        scope_name = params[:scope]
        defined_scope = @resource_class.all_scopes.find { |s| s[:name].to_s == scope_name }
        defined_scope ||= @resource_class.all_scopes.find { |s| s[:default] }
        defined_scope&.dig(:name)&.to_s
      end

      def apply_scopes(scope)
        defined_scope = @resource_class.all_scopes.find { |s| s[:name].to_s == params[:scope] }
        defined_scope ||= @resource_class.all_scopes.find { |s| s[:default] }

        return scope unless defined_scope

        apply_resource_scope(scope, defined_scope[:scope])
      end

      def apply_resource_scope(scope, scope_body)
        return scope.merge(scope_body) unless scope_body.respond_to?(:call)

        scope_body.arity.zero? ? scope.instance_exec(&scope_body) : scope_body.call(scope)
      end

      def apply_sorting(scope)
        sort_col = params[:sort].to_s
        sort_col = IronAdmin.configuration.default_sort.to_s unless adapter.has_column?(sort_col)
        valid_dir = %w[asc desc].include?(params[:direction].to_s.downcase)
        sort_dir = valid_dir ? params[:direction] : IronAdmin.configuration.default_sort_direction
        adapter.order_by(scope, sort_col, sort_dir)
      end

      def apply_preloading(scope)
        preloads = @resource_class.preload_associations
        preloads.any? ? adapter.preload(scope, preloads) : scope
      end
    end
  end
end
