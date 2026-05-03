# frozen_string_literal: true

module IronAdmin
  module Form
    # Renders a select dropdown for belongs_to associations.
    #
    # @example Basic belongs_to select
    #   render IronAdmin::Form::BelongsToComponent.new(
    #     name: "record[organization_id]",
    #     association_class: Organization,
    #     selected: @record.organization_id
    #   )
    class BelongsToComponent < ViewComponent::Base
      # Default limit for options before suggesting autocomplete.
      # @return [Integer]
      DEFAULT_OPTIONS_LIMIT = 100

      # Methods tried (in order) when no explicit `display_method:` is
      # passed and the record doesn't have `:name`. Mirrors
      # `IronAdmin::ApplicationHelper::DISPLAY_METHODS`.
      DISPLAY_METHOD_FALLBACKS = %i[name title email label slug].freeze

      # @return [String] Select name attribute
      attr_reader :name

      # @return [Class] The associated model class
      attr_reader :association_class

      # @return [Integer, nil] Currently selected ID
      attr_reader :selected

      # @return [Symbol] Method to call for display text
      attr_reader :display_method

      # @return [Boolean] Whether to include blank option
      attr_reader :include_blank

      # @return [Boolean] Whether input is disabled
      attr_reader :disabled

      # @return [Boolean] Whether input has error state
      attr_reader :has_error

      # @return [Integer] Max options to load
      attr_reader :options_limit

      # @return [Proc, nil] Custom scope for options
      attr_reader :options_scope

      # @param name [String] Select name
      # @param association_class [Class] Associated model class
      # @param selected [Integer, nil] Selected ID
      # @param display_method [Symbol, Proc, nil] Custom display method.
      #   Pass `nil` (the default) to let the component auto-detect a
      #   sensible label from `IronAdmin::ApplicationHelper::DISPLAY_METHODS`
      #   (`:name`, `:title`, `:email`, `:label`, `:slug`), falling back
      #   to `"<Model> #<id>"` if none of those exist.
      # @param include_blank [Boolean] Include blank option
      # @param disabled [Boolean] Disabled state
      # @param has_error [Boolean] Error state
      # @param options_limit [Integer] Max options
      # @param options_scope [Proc, nil] Custom scope
      def initialize(name:, association_class:, selected: nil, display_method: nil,
                     include_blank: true, disabled: false, has_error: false,
                     options_limit: DEFAULT_OPTIONS_LIMIT, options_scope: nil)
        @name = name
        @association_class = association_class
        @selected = selected
        @display_method = display_method
        @include_blank = include_blank
        @disabled = disabled
        @has_error = has_error
        @options_limit = options_limit
        @options_scope = options_scope
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme configuration
      def theme
        IronAdmin.configuration.theme
      end

      # @api private
      # @return [Array<Array(String, Integer)>] Options array for select tag
      def options
        scope = options_scope ? association_class.instance_exec(&options_scope) : association_adapter.all
        association_adapter.limit(scope, options_limit).map do |record|
          [option_label_for(record), record.id]
        end
      end

      # @api private
      # Resolves the option label for a single record. Mirrors
      # `IronAdmin::ApplicationHelper#display_record_label` so callers
      # who construct the component directly (or test it without
      # rendering) get the same fallback behavior — Proc / Symbol /
      # auto-detect from `DISPLAY_METHOD_FALLBACKS`, then `Model #id`.
      # @param record [Object] The associated record
      # @return [String] The label
      def option_label_for(record)
        return display_method.call(record) if display_method.is_a?(Proc)
        return record.public_send(display_method) if display_method

        DISPLAY_METHOD_FALLBACKS.each do |method|
          value = record.public_send(method) if record.respond_to?(method)
          return value if value.present?
        end

        "#{record.class.model_name.human} ##{record.id}"
      end

      # @api private
      # @return [Boolean] Whether to show hint about more records available
      def show_search_hint?
        association_adapter.count > options_limit
      end

      # @api private
      # @return [String] CSS classes for select element
      def select_classes
        base = "block w-full appearance-none border px-3 py-2 text-sm shadow-sm outline-none " \
               "transition duration-150 ease-in-out #{theme.border_radius} #{theme.input_border} " \
               "#{theme.card_bg} #{theme.body_text} #{theme.input_focus}"
        base += " !border-red-400 !focus:border-red-500 !focus:ring-red-500/20" if has_error
        base += " bg-gray-50 cursor-not-allowed" if disabled
        base
      end

      # @api private
      # @return [String] Inline CSS style for dropdown chevron
      def chevron_style
        "background-image: url(\"data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' " \
          "viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-linecap='round' stroke-linejoin='round' " \
          "stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e\"); background-position: right 0.5rem center; " \
          "background-repeat: no-repeat; background-size: 1.5em 1.5em; padding-right: 2.5rem;"
      end

      private

      # @return [IronAdmin::Adapters::Base] Adapter for the associated model
      def association_adapter
        @association_adapter ||= IronAdmin::Adapters::ActiveRecord.new(association_class)
      end
    end
  end
end
