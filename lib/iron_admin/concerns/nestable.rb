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
        # Declares a has_many association.
        #
        # The show page's related list does not read +:fields+. That option is
        # used only when +nested: true+, as the columns of the nested form.
        # With no +:fields+, the nested form infers the associated model's
        # fields and skips id, created_at, updated_at and the foreign key.
        #
        # @param name [Symbol] The association name
        # @param nested [Boolean] Render a nested form (default: false)
        # @param allow_destroy [Boolean] Allow removing a nested row (default: true)
        # @param position_field [Symbol, nil] Column that stores the nested row order
        # @param fields [Array<Symbol>, nil] Nested-form columns. The related list ignores them.
        # @param options [Hash] Other options, such as +:resource+
        # @return [void]
        #
        # @example Related list
        #   has_many :orders
        #
        # @example Nested form columns
        #   has_many :comments, nested: true, fields: [:body, :created_at]
        def has_many(name, nested: false, allow_destroy: true, position_field: nil, fields: nil, **options)
          self.defined_associations = defined_associations.merge(
            name => {
              kind: :has_many, nested: nested, allow_destroy: allow_destroy,
              position_field: position_field&.to_sym, fields: fields&.map(&:to_sym), **options,
            }
          )
        end

        # Declares a has_one association. +:fields+ feeds the nested form only,
        # the same way as {#has_many}, and does not change a related list.
        #
        # @param fields [Array<Symbol>, nil] Nested-form columns
        # @return [void]
        def has_one(name, nested: false, allow_destroy: true, fields: nil, **options)
          self.defined_associations = defined_associations.merge(
            name => {
              kind: :has_one, nested: nested, allow_destroy: allow_destroy,
              fields: fields&.map(&:to_sym), **options,
            }
          )
        end
      end

      # Reader and resolver for nested associations.
      module NestedReader
        def nested_associations
          defined_associations.select { |_, v| v[:nested] }.map do |assoc_name, config|
            reflection = adapter.association(assoc_name)
            raise ArgumentError, "Unknown association #{assoc_name} for #{model.name}" unless reflection

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
            fields_by_name = FieldInferrer.call(assoc_model).index_by(&:name)
            config[:fields].uniq.filter_map { |name| fields_by_name[name] }
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
