# frozen_string_literal: true

module IronAdmin
  module Concerns
    # The index page's state (scope, search, sort, page and the resource's own
    # filters) as read from the request. Only these known params with String
    # values are kept, so the state is safe to put back into an index URL.
    module IndexStatePreservable
      extend ActiveSupport::Concern

      # Params that hold the index state, besides +filters+.
      INDEX_STATE_KEYS = %w[scope q sort direction page].freeze

      # The sub-params of a +:string+ or +:number+ filter.
      OPERATOR_FILTER_KEYS = %w[op value value_2].freeze

      included do
        helper_method :iron_admin_index_state if respond_to?(:helper_method)
      end

      private

      # @return [Hash{String => String, Hash}] The present index params, with
      #   the visible filters' values nested under "filters"
      def iron_admin_index_state
        @iron_admin_index_state ||= begin
          state = INDEX_STATE_KEYS.index_with { |key| params[key] }.select { |_key, value| index_state_value?(value) }
          filters = iron_admin_visible_filters.reduce({}) { |kept, filter| kept.merge(index_state_filter(filter)) }
          (filters.empty? ? state : state.merge("filters" => filters)).freeze
        end
      end

      def index_state_filter(filter)
        name = filter[:name].to_s
        case filter[:type]
        when :string, :number then index_state_operator_filter(name)
        when :date_range then index_state_filter_values(%W[#{name}_from #{name}_to])
        else index_state_filter_values([name])
        end
      end

      def index_state_operator_filter(name)
        sub = iron_admin_filter_param(name)
        return {} unless sub.is_a?(ActionController::Parameters) && index_state_value?(sub["value"])

        { name => OPERATOR_FILTER_KEYS.index_with { |key| sub[key] }.select { |_key, value| index_state_value?(value) } }
      end

      def index_state_filter_values(keys)
        keys.index_with { |key| iron_admin_filter_param(key) }.select { |_key, value| index_state_value?(value) }
      end

      def index_state_value?(value)
        value.is_a?(String) && value.present?
      end
    end
  end
end
