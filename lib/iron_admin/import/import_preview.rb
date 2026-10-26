# frozen_string_literal: true

module IronAdmin
  module Import
    Row = Struct.new(:number, :attributes, :errors, keyword_init: true) unless const_defined?(:Row)
    Error = Struct.new(:row_number, :message, keyword_init: true) unless const_defined?(:Error)

    ImportPreview = Struct.new(:total_rows, :headers, :mapping, :rows, :errors, keyword_init: true) do
      # Plain text for a type-cast cell value, so the preview shows what will be
      # imported rather than Ruby inspect output (quoted strings, "nil").
      def cell_text(row, field_name)
        value = row.attributes[field_name]

        case value
        when nil then ""
        when Hash, Array then value.to_json
        else value.respond_to?(:strftime) ? preview_time_text(value) : value.to_s
        end
      end

      private

      # The default formats of the show and index pages
      # (FieldDisplayHelper#display_date and #display_datetime), with no locale lookup.
      def preview_time_text(value)
        return value.strftime("%b %d, %Y") unless value.respond_to?(:hour)

        value.strftime("%b %d, %Y at %l:%M %p").squish
      end
    end
  end
end
