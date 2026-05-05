# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Coerces incoming `:json` form params from JSON strings (the textarea
    # content rendered by `_form.html.haml`'s `when :json` branch) back into
    # Ruby `Hash`/`Array`. Without this, the controller would assign the raw
    # textarea string to the model's jsonb/json column, replacing the
    # structured value with a string and silently losing data.
    #
    # Invalid JSON is left as-is so model-side validation can surface the
    # error to the user instead of being swallowed.
    module JsonParamsCoercion
      extend ActiveSupport::Concern

      private

      def coerce_json_field_params!(parsed)
        form_fields.each do |field|
          next unless field.type == :json

          value = parsed[field.name]
          next unless value.is_a?(String)

          # An empty textarea means "clear this field". Storing the empty
          # string would serialize to a JSON string scalar (`""`) instead
          # of clearing the column.
          if value.empty?
            parsed[field.name] = nil
            next
          end

          parsed[field.name] = JSON.parse(value)
        rescue JSON::ParserError
          # Drop the key so the existing column value is preserved instead
          # of being overwritten with the raw string (which AR would then
          # store as a JSON string scalar, silently destroying the prior
          # Hash/Array). The user keeps the form open via model-side
          # validation in the typical case; full inline-error UX is tracked
          # as a follow-up.
          parsed.delete(field.name)
        end
      end
    end
  end
end
