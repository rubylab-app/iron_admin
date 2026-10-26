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
        else value.respond_to?(:strftime) ? I18n.l(value) : value.to_s
        end
      end
    end
  end
end
