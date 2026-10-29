# frozen_string_literal: true

module IronAdmin
  module Ui
    # Renders scope tabs for filtering resource lists. Each tab links to
    # +base_path+ with +params+ and its own scope, without the current scope
    # and page, so switching tabs keeps the search, filters and sort and
    # starts back at the first page.
    #
    # @example Scopes from resource, keeping the index state
    #   render IronAdmin::Ui::ScopesComponent.new(
    #     scopes: @resource_class.all_scopes,
    #     current_scope: @current_scope,
    #     base_path: resources_path(@resource_class.resource_name),
    #     params: iron_admin_index_state
    #   )
    class ScopesComponent < ViewComponent::Base
      # @return [Array<Hash>] Scope definitions
      attr_reader :scopes

      # @return [String, nil] Currently active scope name
      attr_reader :current_scope

      # @return [String] Base URL path
      attr_reader :base_path

      # @return [Hash] Query params the tabs keep
      attr_reader :params

      # Params a tab link never keeps: it sets its own scope and starts back at the first page.
      DROPPED_PARAMS = %w[scope page].freeze

      # @param scopes [Array<Hash>] Scope definitions
      # @param current_scope [String, nil] Active scope name
      # @param base_path [String] Base URL
      # @param params [Hash] Query params the tabs keep, such as +iron_admin_index_state+
      #   (the search, filters and sort); their +scope+ and +page+ are dropped
      def initialize(scopes:, current_scope:, base_path:, params: {})
        @scopes = scopes
        @current_scope = current_scope
        @base_path = base_path
        @params = params
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @param scope_name [Symbol, String] Scope name
      # @return [String] URL with +params+ and the scope, without a page
      def scope_url(scope_name)
        query = params.to_h.stringify_keys.except(*DROPPED_PARAMS).merge("scope" => scope_name.to_s)
        "#{base_path}?#{query.to_query}"
      end

      # @api private
      # @param scope [Hash] Scope definition
      # @return [Boolean] Whether scope is currently active
      def active?(scope)
        current_scope == scope[:name].to_s
      end

      # @api private
      # @param scope [Hash] Scope definition
      # @return [String] CSS classes for scope tab
      def scope_classes(scope)
        base = "px-4 py-2 text-sm font-medium whitespace-nowrap border-b-2 -mb-px transition-colors duration-150 " \
               "#{theme.focus_ring}"
        if active?(scope)
          "#{base} #{theme.scope_active}"
        else
          "#{base} #{theme.scope_inactive}"
        end
      end

      # @api private
      # @return [Boolean] Whether to render the component
      def render?
        scopes.any?
      end
    end
  end
end
