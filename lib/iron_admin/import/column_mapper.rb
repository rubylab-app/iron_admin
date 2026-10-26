# frozen_string_literal: true

module IronAdmin
  module Import
    class ColumnMapper
      def initialize(resource_class, current_user: nil)
        @resource_class = resource_class
        @current_user = current_user
      end

      # Maps each recognised header to its field name. The mapping follows the
      # importable fields' order (import_fields), so the preview lists its
      # columns as the upload form does; headers for the same field keep the
      # file's order.
      def map_headers(headers)
        fields = @resource_class.importable_fields(@current_user)
        candidates = field_candidates(fields)
        headers_by_field = headers.group_by { |header| candidates[normalize(header)]&.name }

        fields.each_with_object({}) do |field, mapping|
          headers_by_field.fetch(field.name, []).each { |header| mapping[header] = field.name }
        end
      end

      private

      def field_candidates(fields)
        fields.each_with_object({}) do |field, candidates|
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
