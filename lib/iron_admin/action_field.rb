# frozen_string_literal: true

module IronAdmin
  # Value object representing a single field in an action form.
  #
  # ActionFields define what inputs are shown to the user when an action
  # requires parameters before execution (e.g., a reason, a date, a choice).
  #
  # @example Creating an action field
  #   ActionField.new(name: :reason, type: :textarea, required: true)
  #
  # @example Creating a select field with options
  #   ActionField.new(name: :priority, type: :select, options: %w[low medium high])
  class ActionField
    # Supported field types for action forms.
    TYPES = %i[text textarea number boolean date datetime select].freeze

    # @return [Symbol] The field name (used as the param key)
    attr_reader :name

    # @return [Symbol] The field type
    attr_reader :type

    # @return [String] Human-readable label for the field
    attr_reader :label

    # @return [Boolean] Whether the field is required
    attr_reader :required

    # @return [Object, nil] Default value for the field
    attr_reader :default

    # @return [String, nil] Placeholder text for the input
    attr_reader :placeholder

    # @return [Array, nil] Options for select fields
    attr_reader :options

    # @param name [Symbol, String] The field name (converted to Symbol)
    # @param type [Symbol, String] The field type (defaults to :text)
    # @param label [String, nil] Custom label (inferred from name if nil)
    # @param required [Boolean] Whether the field is required (default: false)
    # @param default [Object, nil] Default value for the field
    # @param placeholder [String, nil] Placeholder text
    # @param options [Array, nil] Options for select fields
    def initialize(name:, type: :text, label: nil, required: false, default: nil, placeholder: nil, options: nil)
      @name = name.to_sym
      @type = TYPES.include?(type.to_sym) ? type.to_sym : :text
      @label = label || name.to_s.humanize
      @required = required
      @default = default
      @placeholder = placeholder
      @options = options
    end
  end
end
