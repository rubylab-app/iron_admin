# frozen_string_literal: true

module IronAdmin
  # Value object representing a nested association configured for inline editing.
  #
  # Wraps the resolved configuration from the Resource DSL (has_many/has_one with nested: true)
  # into a structured object used by the NestedFormComponent and strong parameter builder.
  #
  # @see IronAdmin::Resource.nested_associations
  NestedAssociation = Struct.new(
    :name, :kind, :reflection, :fields,
    :allow_destroy, :position_field,
    keyword_init: true
  )
end
