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
      # @param input_id [String, nil] Id of the visible text input, for a label to point at.
      #   Defaults to "<component_id>-input".
      # @param resource_name [String] Resource for autocomplete
      # @param selected_id [Integer, nil] Selected ID
      # @param selected_label [String, nil] Selected label
      # @param placeholder [String, nil] Placeholder
      # @param disabled [Boolean] Disabled state
      # @param has_error [Boolean] Error state
      # @param field [IronAdmin::Field, nil] Field config
      # @param current_user [Object, nil] Current user
      def initialize(name:, resource_name:, input_id: nil, selected_id: nil, selected_label: nil,
                     placeholder: nil, disabled: false, has_error: false,
                     field: nil, current_user: nil)
        @name = name
        @input_id = input_id
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
        ControlClasses.input(theme, error: has_error, muted: effectively_disabled?)
      end

      # @api private
      # @return [String] CSS classes for autocomplete dropdown panel
      def dropdown_classes
        "absolute z-50 mt-1 w-full max-h-60 overflow-auto p-1 #{theme.border_radius} #{theme.border_width} " \
          "#{theme.card_border} #{theme.popover_background} #{theme.popover_shadow}"
      end

      # @api private
      # @return [String] CSS classes for dropdown list items
      def dropdown_item_classes
        "px-2.5 py-1.5 text-sm cursor-pointer #{theme.control_radius} #{theme.body_text} #{theme.item_hover}"
      end

      # @api private
      # @return [String] CSS classes of the item shown when nothing matches
      def empty_item_classes
        "px-2.5 py-1.5 text-sm #{theme.muted_text}"
      end

      # @api private
      # @return [String] Unique component DOM ID
      def component_id
        @component_id ||= "autocomplete-#{SecureRandom.hex(4)}"
      end

      # @api private
      # @return [String] DOM id of the visible text input
      def input_id
        @input_id || "#{component_id}-input"
      end

      # @api private
      # @return [String] DOM id of the results listbox
      def listbox_id
        "#{component_id}-dropdown"
      end
    end
  end
end
