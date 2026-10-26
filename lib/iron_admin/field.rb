# frozen_string_literal: true

module IronAdmin
  # Represents a field configuration for a resource.
  #
  # Fields are typically inferred from the database schema via {FieldInferrer},
  # then customized via the {Resource.field} DSL. Each Field instance holds
  # the configuration for how a column/attribute should be displayed and edited.
  #
  # @example Field from database schema
  #   # Automatically inferred for a string column
  #   Field.new(:name, type: :string)
  #
  # @example Field with visibility control
  #   Field.new(:salary, type: :integer, visible: ->(user) { user.hr? })
  #
  # @example Field with multiple options
  #   Field.new(:status, type: :select, options: %w[pending active completed])
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

    # @return [Symbol] The field type (:string, :text, :integer, :boolean,
    #   :date, :datetime, :select, :belongs_to, etc.)
    attr_reader :type

    # @return [Boolean, Proc] Whether the field is visible
    attr_reader :visible

    # @return [Boolean, Proc] Whether the field is read-only
    attr_reader :readonly

    # @return [Hash] Additional field options (e.g., :options, :format, :autocomplete)
    attr_reader :options

    # Creates a new Field instance.
    #
    # @param name [Symbol] The field/column name
    # @param options [Hash] Configuration options
    # @option options [Symbol] :type The field type
    # @option options [Boolean, Proc] :visible Whether the field is visible
    #   (default: true). If a Proc, receives the current user.
    # @option options [Boolean, Proc] :readonly Whether the field is read-only
    #   (default: false). If a Proc, receives the current user.
    # @option options [String] :label Custom display label
    # @option options [Array] :options For select fields, available choices
    # @option options [Boolean] :autocomplete For belongs_to, force autocomplete mode
    # @option options [Proc] :format Custom formatting proc for display
    #
    # @example Basic field
    #   Field.new(:email, type: :string)
    #
    # @example Conditional visibility
    #   Field.new(:ssn, type: :string, visible: ->(user) { user.admin? })
    #
    # @example Select field with options
    #   Field.new(:priority, type: :select, options: %w[low medium high])
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
