# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Provides nested association support for Resource classes.
    #
    # Extends has_many/has_one with nested: kwargs, adds nested_associations
    # reader, and field resolution.
    module Nestable
      extend ActiveSupport::Concern

      # DSL methods for declaring has_many/has_one with nested options.
      module AssociationDsl
        def has_many(name, nested: false, allow_destroy: true, position_field: nil, fields: nil, **options)
          self.defined_associations = defined_associations.merge(
            name => {
              kind: :has_many, nested: nested, allow_destroy: allow_destroy,
              position_field: position_field&.to_sym, fields: fields, **options,
            }
          )
        end

        def has_one(name, nested: false, allow_destroy: true, fields: nil, **options)
          self.defined_associations = defined_associations.merge(
            name => {
              kind: :has_one, nested: nested, allow_destroy: allow_destroy,
              fields: fields, **options,
            }
          )
        end
      end

      # Reader and resolver for nested associations.
      module NestedReader
        def nested_associations
          defined_associations.select { |_, v| v[:nested] }.map do |assoc_name, config|
            reflection = model.reflect_on_association(assoc_name)
            NestedAttributesValidator.validate!(model, assoc_name)
            fields = resolve_nested_fields(config, reflection.klass, reflection.foreign_key)

            NestedAssociation.new(
              name: assoc_name, kind: config[:kind], reflection: reflection,
              fields: fields, allow_destroy: config.fetch(:allow_destroy, true),
              position_field: config[:position_field]
            )
          end
        end

        private

        def resolve_nested_fields(config, assoc_model, foreign_key)
          if config[:fields]
            FieldInferrer.call(assoc_model).select { |f| config[:fields].include?(f.name) }
          else
            skip = %i[id created_at updated_at] + [foreign_key.to_sym]
            FieldInferrer.call(assoc_model).reject { |f| skip.include?(f.name) }
          end
        end
      end

      class_methods do
        include AssociationDsl
        include NestedReader
      end
    end
  end
end
