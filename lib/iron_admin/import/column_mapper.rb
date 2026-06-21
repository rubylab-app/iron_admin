# frozen_string_literal: true

module IronAdmin
  module Import
    class ColumnMapper
      def initialize(resource_class, current_user: nil)
        @resource_class = resource_class
        @current_user = current_user
      end

      def map_headers(headers)
        candidates = field_candidates

        headers.each_with_object({}) do |header, mapping|
          field = candidates[normalize(header)]
          mapping[header] = field.name if field
        end
      end

      private

      def field_candidates
        @resource_class.importable_fields(@current_user).each_with_object({}) do |field, candidates|
          candidate_labels(field).each { |label| candidates[normalize(label)] = field }
        end
      end

      def candidate_labels(field)
        [
          field.name,
          field.name.to_s,
          field.name.to_s.humanize,
          field.options[:label],
        ].compact
      end

      def normalize(value)
        value.to_s.downcase.gsub(/[^a-z0-9]/, "")
      end
    end
  end
end
