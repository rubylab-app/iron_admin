# frozen_string_literal: true

module IronAdmin
  # Assignable association records and the value key their selects submit.
  module AssignableRecordsHelper
    # Records a person may pick for an association, after the tenant scope.
    #
    # @param model_class [Class] associated model
    # @return [ActiveRecord::Relation]
    def assignable_records(model_class)
      IronAdmin::TenantScope.apply(model_class.all)
    end

    # Key a select for +association_name+ must submit.
    #
    # The association's foreign-key target when +model_class+ reflects that
    # association, otherwise +:id+.
    #
    # @param model_class [Class] model that declares the association
    # @param association_name [Symbol, String]
    # @return [Symbol]
    def association_value_key(model_class, association_name)
      return :id unless model_class.respond_to?(:reflect_on_association)

      reflection = model_class.reflect_on_association(association_name)
      return :id unless reflection

      key = reflection.try(:association_primary_key)
      key.is_a?(String) || key.is_a?(Symbol) ? key.to_sym : :id
    end
  end
end
