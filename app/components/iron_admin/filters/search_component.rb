# frozen_string_literal: true

module IronAdmin
  module Filters
    # Renders the search input in the filter bar.
    class SearchComponent < ViewComponent::Base
      # @return [String, nil] Current search value
      attr_reader :value

      # @return [String] Placeholder text
      attr_reader :placeholder

      # @return [String] Form submission URL
      attr_reader :form_url

      # @return [Hash] Hidden params to preserve
      attr_reader :hidden_params

      # @return [Class, nil] The resource being searched
      attr_reader :resource_class

      # @param form_url [String] Form submission URL
      # @param value [String, nil] Current value
      # @param placeholder [String] Placeholder text
      # @param hidden_params [Hash] Hidden params
      # @param resource_class [Class, nil] The resource being searched, which names the input
      def initialize(form_url:, value: nil, placeholder: "Search...", hidden_params: {}, resource_class: nil)
        @value = value
        @placeholder = placeholder
        @form_url = form_url
        @hidden_params = hidden_params
        @resource_class = resource_class
      end

      # @api private
      # @return [String] Accessible name of the search input
      def label
        return placeholder unless resource_class

        I18n.t("iron_admin.resources.index.search_label", resource: resource_class.label)
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] CSS classes for search input field
      def input_classes
        "block w-full border py-2 pl-10 pr-4 text-sm shadow-sm outline-none " \
          "transition duration-150 ease-in-out #{theme.border_radius} #{theme.input_border} " \
          "#{theme.navbar_search_bg} #{theme.body_text} #{theme.input_focus} #{theme.navbar_search_focus_bg}"
      end
    end
  end
end
