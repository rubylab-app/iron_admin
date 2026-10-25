# frozen_string_literal: true

module IronAdmin
  module Form
    # Renders an autocomplete input for belongs_to associations with many records.
    #
    # Used automatically when association has more than 100 records,
    # or can be forced via `autocomplete: true` option.
    #
    # @example Autocomplete for large association
    #   render IronAdmin::Form::BelongsToAutocompleteComponent.new(
    #     name: "record[customer_id]",
    #     resource_name: "customers",
    #     selected_id: @record.customer_id,
    #     selected_label: @record.customer&.name
    #   )
    class BelongsToAutocompleteComponent < ViewComponent::Base
      include Concerns::FormInputBehavior

      # @return [String] Input name attribute
      attr_reader :name

      # @return [String] Resource name for autocomplete URL
      attr_reader :resource_name

      # @return [Integer, nil] Currently selected ID
      attr_reader :selected_id

      # @return [String, nil] Display label for selected record
      attr_reader :selected_label

      # @return [String] Placeholder text
      attr_reader :placeholder

      # @return [Boolean] Whether input has error state
      attr_reader :has_error

      # @return [String] Autocomplete endpoint URL
      attr_accessor :autocomplete_url

      # @param name [String] Input name
      # @param resource_name [String] Resource for autocomplete
      # @param selected_id [Integer, nil] Selected ID
      # @param selected_label [String, nil] Selected label
      # @param placeholder [String, nil] Placeholder
      # @param disabled [Boolean] Disabled state
      # @param has_error [Boolean] Error state
      # @param field [IronAdmin::Field, nil] Field config
      # @param current_user [Object, nil] Current user
      def initialize(name:, resource_name:, selected_id: nil, selected_label: nil,
                     placeholder: nil, disabled: false, has_error: false,
                     field: nil, current_user: nil)
        @name = name
        @resource_name = resource_name
        @selected_id = selected_id
        @selected_label = selected_label
        @placeholder = placeholder || "Search..."
        @disabled = disabled
        @has_error = has_error
        @field = field
        @current_user = current_user
      end

      # @api private
      # Sets the autocomplete URL before rendering.
      # @return [void]
      def before_render
        self.autocomplete_url = helpers.iron_admin.autocomplete_path(resource_name)
      end

      # @api private
      # @return [String] CSS classes for text input field
      def input_classes
        base = "block w-full border px-3 py-2 text-sm shadow-sm outline-none transition duration-150 ease-in-out " \
               "#{theme.border_radius} #{theme.input_border} #{theme.card_bg} #{theme.body_text} #{theme.input_focus}"
        base += " !border-red-400 focus:!border-red-500 focus:!ring-red-500/20" if has_error
        base += " bg-gray-50 cursor-not-allowed" if effectively_disabled?
        base
      end

      # @api private
      # @return [String] CSS classes for autocomplete dropdown panel
      def dropdown_classes
        "absolute z-50 mt-1 w-full max-h-60 overflow-auto #{theme.border_radius} " \
          "#{theme.card_bg} border #{theme.input_border} shadow-lg"
      end

      # @api private
      # @return [String] CSS classes for dropdown list items
      def dropdown_item_classes
        "px-3 py-2 text-sm cursor-pointer hover:bg-gray-100 #{theme.body_text}"
      end

      # @api private
      # @return [String] Unique component DOM ID
      def component_id
        @component_id ||= "autocomplete-#{SecureRandom.hex(4)}"
      end
    end
  end
end
