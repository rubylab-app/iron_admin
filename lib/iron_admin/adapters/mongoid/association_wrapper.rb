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
          @macro = MACRO_MAP.fetch(raw_macro_for(relation), raw_macro_for(relation))
        end

        private

        # Mongoid 9 dropped `Association#macro`. Derive the macro symbol
        # from the association class name instead, e.g.
        # `Mongoid::Association::Referenced::BelongsTo` → :belongs_to,
        # `Mongoid::Association::Embedded::EmbedsMany` → :embeds_many.
        # Falls back to `relation.macro` when defined (Mongoid <= 8).
        #
        # @param relation [Object] A Mongoid association metadata instance
        # @return [Symbol] The macro symbol (e.g. :belongs_to, :has_many,
        #   :embeds_many, :embedded_in)
        def raw_macro_for(relation)
          return relation.macro if relation.respond_to?(:macro)

          relation.class.name.split("::").last.underscore.to_sym
        end

        public

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
