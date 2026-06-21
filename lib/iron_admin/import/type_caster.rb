# frozen_string_literal: true

require "json"
require "time"

module IronAdmin
  module Import
    class TypeCaster
      def cast(value, field)
        return nil if blank_value?(value)

        case field.type
        when :boolean then cast_boolean(value)
        when :integer then Integer(value)
        when :float then Float(value)
        when :decimal then BigDecimal(value.to_s)
        when :number then cast_number(value)
        when :json then cast_json(value)
        when :date then Date.parse(value.to_s)
        when :datetime then Time.zone.parse(value.to_s)
        else value
        end
      end

      private

      def blank_value?(value)
        value.nil? || (value.is_a?(String) && value.strip.blank?)
      end

      def cast_boolean(value)
        ::ActiveModel::Type::Boolean.new.cast(value)
      end

      def cast_number(value)
        string = value.to_s
        string.include?(".") ? Float(string) : Integer(string)
      end

      def cast_json(value)
        return value if value.is_a?(Hash) || value.is_a?(Array)

        ::JSON.parse(value.to_s)
      end
    end
  end
end
