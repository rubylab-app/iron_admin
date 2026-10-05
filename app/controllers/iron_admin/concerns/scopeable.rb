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

      def record_scope(include_deleted: false)
        scope = base_scope
        return scope unless include_deleted && @resource_class.soft_delete?

        adapter.unscope_column(scope, @resource_class.soft_delete_column)
      end

      # Resolves bulk ids through the real primary key, including composite keys.
      #
      # @param ids [Array]
      # @return [Array(Array<String>, Object)] requested ids and the matching relation
      def find_bulk_records(ids)
        requested = Array(ids).map(&:to_s).uniq
        [requested, relation_for_bulk_ids(requested)]
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

      def relation_for_bulk_ids(ids)
        primary_key = adapter.primary_key
        return adapter.filter(base_scope, primary_key.to_sym, ids) unless primary_key.is_a?(Array)

        relations = ids.filter_map { |id| composite_bulk_relation(primary_key, id) }
        return base_scope.none if relations.empty?

        relations.reduce { |combined, relation| combined.or(relation) }
      end

      def composite_bulk_relation(primary_key, id)
        parts = id.to_s.split("_")
        return if parts.size != primary_key.size

        base_scope.where(primary_key.zip(parts).to_h)
      end
    end
  end
end
