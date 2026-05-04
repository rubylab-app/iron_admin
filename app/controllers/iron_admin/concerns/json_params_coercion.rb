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
          next if value.empty?

          parsed[field.name] = JSON.parse(value)
        rescue JSON::ParserError
          next
        end
      end
    end
  end
end
