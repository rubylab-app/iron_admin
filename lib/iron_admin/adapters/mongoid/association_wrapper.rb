# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Mongoid
      # Wraps a Mongoid relation metadata object to present the interface
      # expected by FieldInferrer and other IronAdmin consumers.
      #
      # Normalizes Mongoid's embedded association macros to their IronAdmin
      # equivalents: embeds_many → :has_many, embeds_one → :has_one,
      # embedded_in → :belongs_to.
      class AssociationWrapper
        # @return [Symbol] The association name
        attr_reader :name

        # @return [Symbol] The normalized macro (:belongs_to, :has_many, :has_one, :has_and_belongs_to_many)
        attr_reader :macro

        MACRO_MAP = {
          embeds_many: :has_many,
          embeds_one: :has_one,
          embedded_in: :belongs_to,
        }.freeze

        def initialize(relation)
          @relation = relation
          @name = relation.name.to_sym
          @macro = MACRO_MAP.fetch(relation.macro, relation.macro)
        end

        def klass
          @relation.class_name.constantize
        rescue NameError
          nil
        end

        def foreign_key
          return "" unless @relation.respond_to?(:foreign_key)

          @relation.foreign_key.to_s
        end

        def polymorphic?
          return false unless @relation.respond_to?(:polymorphic?)

          @relation.polymorphic?
        end

        def foreign_type
          "#{@name}_type"
        end
      end
    end
  end
end
