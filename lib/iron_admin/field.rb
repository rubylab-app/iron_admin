# frozen_string_literal: true

module IronAdmin
  # Represents a field configuration for a resource.
  #
  # Fields are typically inferred from the database schema via {FieldInferrer},
  # then customized via the {Resource.field} DSL. Each Field instance holds
  # the configuration for how a column/attribute should be displayed and edited.
  #
  # @example Field from a string column
  #   # Inferred type for a string column. :string is not a field type.
  #   Field.new(:name, type: :text)
  #
  # @example Field with visibility control
  #   Field.new(:salary, type: :number, visible: ->(user) { user.hr? })
  #
  # @example Select field
  #   # choices:, not options:. options: is the filter key.
  #   Field.new(:status, type: :select, choices: %w[pending active completed])
  #
  # @see IronAdmin::Resource.field For the DSL to configure fields
  # @see IronAdmin::FieldInferrer For automatic field inference
  class Field
    # Types whose value the UI never shows. Search, sort, inferred filters and
    # default exports leave such fields out, so readers cannot probe the value.
    # @return [Array<Symbol>]
    SECRET_TYPES = %i[password hidden].freeze

    # @return [Symbol] The field/column name
    attr_reader :name

    # @return [Symbol] The field type (:text, :textarea, :number, :boolean,
    #   :date, :datetime, :select, :belongs_to, and the other types
    #   {Resource.field} documents). :string and :integer are not types.
    attr_reader :type

    # @return [Boolean, Proc] Whether the field is visible
    attr_reader :visible

    # @return [Boolean, Proc] Whether the field is read-only
    attr_reader :readonly

    # @return [Hash] Additional field options (e.g., :choices, :format, :autocomplete)
    attr_reader :options

    # Creates a new Field instance.
    #
    # @param name [Symbol] The field/column name
    # @param options [Hash] Configuration options
    # @option options [Symbol] :type The field type. See {Resource.field} for the
    #   types the inferrer and the form actually use. :string and :integer render
    #   a text input.
    # @option options [Boolean, Proc] :visible Whether the field is visible
    #   (default: true). If a Proc, receives the current user.
    # @option options [Boolean, Proc] :readonly Whether the field is read-only
    #   (default: false). If a Proc, receives the current user.
    # @option options [String] :label No effect on page labels, which humanize the
    #   name. Import column matching uses it as an extra header candidate.
    # @option options [Array] :choices Choices for a :select field. The form reads
    #   :choices. :options is the filter key.
    # @option options [Boolean] :autocomplete For belongs_to, force autocomplete mode
    # @option options [String] :format strftime pattern for a :date or :datetime.
    #   A Proc is not called. See {Resource.field}.
    #
    # @example Basic field
    #   Field.new(:email, type: :text)
    #
    # @example Conditional visibility
    #   Field.new(:ssn, type: :text, visible: ->(user) { user.admin? })
    #
    # @example Select field
    #   Field.new(:priority, type: :select, choices: %w[low medium high])
    def initialize(name, **options)
      @name = name
      @type = options.delete(:type)
      @visible = options.delete(:visible) { true }
      @readonly = options.delete(:readonly) { false }
      @options = options
    end

    # Checks if the field is visible for the given user.
    #
    # @param user [Object] The current user object
    # @return [Boolean] True if the field should be displayed
    #
    # @example
    #   field.visible?(current_user)  #=> true
    def visible?(user)
      evaluate(@visible, user)
    end

    # Checks if the field is read-only for the given user.
    #
    # @param user [Object] The current user object
    # @return [Boolean] True if the field should be non-editable
    #
    # @example
    #   field.readonly?(current_user)  #=> false
    def readonly?(user)
      evaluate(@readonly, user)
    end

    # Whether the field's type is one of {SECRET_TYPES}.
    #
    # @return [Boolean]
    def secret?
      SECRET_TYPES.include?(type)
    end

    private

    # @api private
    # Evaluates a value that may be a Proc or a static value.
    def evaluate(value, context)
      value.is_a?(Proc) ? value.call(context) : value
    end
  end
end
