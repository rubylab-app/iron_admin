# frozen_string_literal: true

module IronAdmin
  module Import
    Row = Struct.new(:number, :attributes, :errors, keyword_init: true) unless const_defined?(:Row)
    Error = Struct.new(:row_number, :message, keyword_init: true) unless const_defined?(:Error)

    # `fields` maps each mapped field name to its {IronAdmin::Field}, so each
    # cell can be formatted as the show page displays that field.
    ImportPreview = Struct.new(:total_rows, :headers, :mapping, :rows, :errors, :fields, keyword_init: true) do
      # Plain text for a type-cast cell value, formatted as the show page
      # displays the column's field (Yes/No, date formats, currency) instead of
      # Ruby output. Only the text changes: the attributes the import saves stay as cast.
      def cell_text(row, field_name)
        value = row.attributes[field_name]
        return "" if value.nil?

        field_text(value, fields.to_h[field_name]) || plain_text(value)
      end

      private

      # @return [String, nil] nil when the field's type has no formatting for the value
      def field_text(value, field)
        case field&.type
        when :boolean then boolean_text(value)
        when :date, :datetime then field_time_text(value, field)
        when :currency then currency_text(value, field)
        when :badge, :radio then value.to_s.humanize
        when *Field::SECRET_TYPES then "\u2022" * 8 # The show page's password mask
        end
      end

      def plain_text(value)
        case value
        when Hash, Array then value.to_json
        else value.respond_to?(:strftime) ? preview_time_text(value) : value.to_s
        end
      end

      # The show page's labels (FieldDisplayHelper#display_boolean), with
      # defaults for a locale that has none.
      def boolean_text(value)
        case value
        when true then I18n.t("iron_admin.fields.boolean_true", default: "Yes")
        when false then I18n.t("iron_admin.fields.boolean_false", default: "No")
        end
      end

      # FieldDisplayHelper#display_date and #display_datetime: the field's
      # format, or the default one.
      def field_time_text(value, field)
        return unless value.respond_to?(:strftime)

        pattern = field.options[:format]
        return preview_time_text(value, date_only: field.type == :date) unless pattern.is_a?(String)

        text = value.strftime(pattern)
        field.type == :datetime ? text.squish : text
      end

      # FieldDisplayHelper#display_currency, for a value that is a number.
      def currency_text(value, field)
        number = value.is_a?(Numeric) ? value : Float(value.to_s, exception: false)
        return unless number

        precision = field.options[:precision] || 2
        amount = ActiveSupport::NumberHelper.number_to_delimited(format("%.#{precision}f", number.to_f))
        "#{field.options[:symbol] || "$"}#{amount}"
      end

      # The default formats of the show and index pages
      # (FieldDisplayHelper#display_date and #display_datetime), with no locale lookup.
      def preview_time_text(value, date_only: !value.respond_to?(:hour))
        return value.strftime("%b %d, %Y") if date_only

        value.strftime("%b %d, %Y at %l:%M %p").squish
      end
    end
  end
end
