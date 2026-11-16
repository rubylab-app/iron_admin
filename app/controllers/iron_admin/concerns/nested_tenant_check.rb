# frozen_string_literal: true

module IronAdmin
  module Concerns
    # In-memory tenant check for nested attribute rows before a write.
    module NestedTenantCheck
      extend ActiveSupport::Concern

      private

      # @param record [Object]
      # @param source [Hash, nil]
      # @return [Symbol] +:inside+, +:outside+, or +:unknown+
      def nested_rows_verdict(record, source)
        return :inside if source.nil?

        verdict = :inside
        string_keyed(source).each do |key, value|
          nested = nested_for_attributes(key)
          next unless nested

          verdict = rows_verdict(record, nested, value)
          break unless verdict == :inside
        end
        verdict
      end

      # @param key [String]
      # @return [Object, nil]
      def nested_for_attributes(key)
        return unless key.end_with?("_attributes")

        name = key.delete_suffix("_attributes")
        @resource_class.nested_associations.find { |nested| nested.name.to_s == name }
      end

      # @param record [Object]
      # @param nested [Object]
      # @param rows [Hash, Array, nil]
      # @return [Symbol]
      def rows_verdict(record, nested, rows)
        verdict = :inside
        nested_attribute_rows(nested, rows).each do |row|
          verdict = nested_row_verdict(record, nested, row)
          break unless verdict == :inside
        end
        verdict
      end

      # A +:has_one+ entry is one row. A +:has_many+ entry is an Array or an
      # index-to-row Hash, matching {TenantAssignable}.
      #
      # @param nested [Object]
      # @param rows [Hash, Array, nil]
      # @return [Array]
      def nested_attribute_rows(nested, rows)
        return [] if rows.nil?
        return [rows] if nested.kind == :has_one
        return rows if rows.is_a?(Array)

        string_keyed(rows).values
      end

      # @param record [Object]
      # @param nested [Object]
      # @param row [Hash]
      # @return [Symbol]
      def nested_row_verdict(record, nested, row)
        attributes = string_keyed(row)
        return :inside if destroy_row?(attributes)

        scope = IronAdmin::TenantScope.apply(nested.reflection.klass.all)
        candidate = nested_candidate(record, nested, attributes, scope)
        return :unknown if candidate.nil?

        adapter.scope_match(scope, candidate)
      end

      # @param record [Object]
      # @param nested [Object]
      # @param attributes [Hash]
      # @param scope [Object]
      # @return [Object, nil]
      def nested_candidate(record, nested, attributes, scope)
        return adapter.build_in(scope, attributes) if attributes["id"].blank?

        child = nested_child(record, nested, attributes["id"])
        return nil if child.nil?

        adapter.preview(child, attributes)
      end

      # @param record [Object]
      # @param nested [Object]
      # @param id [String, Integer]
      # @return [Object, nil]
      def nested_child(record, nested, id)
        associated = record.public_send(nested.name)
        return single_child(associated, id) if nested.kind == :has_one
        return nil if associated.nil?

        associated.to_a.find { |child| same_id?(child, id) }
      end

      # @param associated [Object, nil]
      # @param id [String, Integer]
      # @return [Object, nil]
      def single_child(associated, id)
        return associated if same_id?(associated, id)

        nil
      end

      # @param child [Object, nil]
      # @param id [String, Integer]
      # @return [Boolean]
      def same_id?(child, id)
        !child.nil? && child.id.to_s == id.to_s
      end

      # @param attributes [Hash]
      # @return [Boolean, nil]
      def destroy_row?(attributes)
        ActiveModel::Type::Boolean.new.cast(attributes["_destroy"])
      end

      # @param attrs [Hash, ActionController::Parameters]
      # @return [Hash]
      def string_keyed(attrs)
        source = attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h : attrs.to_h
        source.each_with_object({}) { |(key, value), copy| copy[key.to_s] = value }
      end
    end
  end
end
