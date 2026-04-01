# frozen_string_literal: true

module IronAdmin
  # Guard object that validates a model declares accepts_nested_attributes_for
  # for a given association before allowing nested form configuration.
  #
  # Called during Resource.nested_associations resolution. Raises ArgumentError
  # if the model is misconfigured.
  #
  # @example
  #   NestedAttributesValidator.validate!(Order, :line_items)
  class NestedAttributesValidator
    # @param model_class [Class] The ActiveRecord model class
    # @param association_name [Symbol, String] The association name to check
    # @raise [ArgumentError] if the model does not declare accepts_nested_attributes_for
    # @return [void]
    def self.validate!(model_class, association_name)
      return if model_class.nested_attributes_options.key?(association_name.to_sym)

      raise ArgumentError,
            "#{model_class} must declare `accepts_nested_attributes_for :#{association_name}` " \
            "to use nested forms in IronAdmin"
    end
  end
end
