# frozen_string_literal: true

module IronAdmin
  module Adapters
    class Http
      # Represents a single record from an HTTP API response.
      #
      # Provides dynamic attribute access, change tracking, and
      # ActiveModel-compatible persistence state methods.
      class Record
        attr_reader :id

        def initialize(attrs = {})
          @force_new = true if attrs.delete(:_persisted) == false
          @attributes = attrs.transform_keys(&:to_s)
          @id = @attributes["id"]
          @persisted = @force_new ? false : !@id.nil?
          @changes = {}
          @previous_changes = {}
        end

        def to_param
          @id&.to_s
        end

        def persisted?
          @persisted
        end

        def new_record?
          !persisted?
        end

        def attributes
          @attributes.dup
        end

        def [](key)
          @attributes[key.to_s]
        end

        def assign_attributes(new_attrs)
          new_attrs.each do |key, value|
            key_s = key.to_s
            old_value = @attributes[key_s]
            next if old_value == value

            @changes[key_s] = [old_value, value]
            @attributes[key_s] = value
          end
        end

        def changes
          @changes.dup
        end

        def previous_changes
          @previous_changes.dup
        end

        def mark_as_persisted
          @previous_changes = @changes.dup
          @changes = {}
          @id = @attributes["id"]
          @persisted = true
        end

        def respond_to_missing?(method_name, include_private = false)
          @attributes.key?(method_name.to_s) || super
        end

        def method_missing(method_name, *args)
          key = method_name.to_s
          return @attributes[key] if @attributes.key?(key)

          super
        end
      end
    end
  end
end
