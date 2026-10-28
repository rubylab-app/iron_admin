# frozen_string_literal: true

module IronAdmin
  # Filter components for search and filtering records.
  module Filters
    # Renders the filter bar containing search and filter controls. Applying
    # or clearing the filters keeps the scope, search query and sort.
    class BarComponent < ViewComponent::Base
      renders_many :filters

      # @return [String] Form submission URL
      attr_reader :form_url

      # @return [String, nil] Current scope
      attr_reader :scope

      # @return [String, nil] Current search query
      attr_reader :query

      # @return [Integer] Number of active filters
      attr_reader :active_count

      # @return [String, nil] Column the index is sorted by
      attr_reader :current_sort

      # @return [String, nil] Sort direction ("asc" or "desc")
      attr_reader :current_direction

      # @param form_url [String] Form submission URL
      # @param scope [String, nil] Current scope
      # @param query [String, nil] Current query
      # @param active_count [Integer] Active filter count
      # @param current_sort [String, nil] Current sort column, kept when filtering
      # @param current_direction [String, nil] Current sort direction, kept when filtering
      def initialize(form_url:, scope: nil, query: nil, active_count: 0, current_sort: nil, current_direction: nil)
        @form_url = form_url
        @scope = scope
        @query = query
        @active_count = active_count
        @current_sort = current_sort
        @current_direction = current_direction
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [Hash{String => String}] The sort and direction the form keeps, when set
      def sort_params
        { "sort" => current_sort, "direction" => current_direction }.compact_blank
      end

      # @api private
      # @return [String] Index URL without filters, keeping the scope, search query and sort
      def clear_url
        state = { "scope" => scope, "q" => query }.compact_blank.merge(sort_params)
        return form_url if state.empty?

        "#{form_url}#{form_url.include?("?") ? "&" : "?"}#{state.to_query}"
      end

      # @api private
      # @return [Boolean] Whether any filters are active
      def has_active_filters?
        active_count.positive?
      end

      # @api private
      # @return [String] CSS classes for filter dropdown trigger button
      def trigger_classes
        ControlStyles.trigger(theme)
      end

      # @api private
      # @return [String] CSS classes for filter dropdown panel
      def dropdown_classes
        ControlStyles.panel(theme)
      end

      # @api private
      # @return [String] CSS classes of the active filter count
      def count_classes
        ControlStyles.count(theme)
      end

      # @api private
      # @return [String] CSS classes of the Apply and Clear row
      def footer_classes
        ControlStyles.footer(theme)
      end

      # @api private
      # @return [String] CSS classes of the Apply button
      def apply_classes
        ControlStyles.apply_button(theme)
      end

      # @api private
      # @return [String] CSS classes of the Clear link
      def clear_classes
        ControlStyles.clear_button(theme)
      end
    end
  end
end
