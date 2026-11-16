# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Omits blank password params so an empty input does not clear the stored value.
    module BlankPasswordFilterable
      extend ActiveSupport::Concern

      private

      # Password inputs never render the stored value, so a blank one means "unchanged".
      #
      # @param attrs [Hash, ActionController::Parameters] permitted attributes
      # @return [Hash, ActionController::Parameters]
      def without_blank_passwords(attrs)
        names = password_field_names
        attrs.reject { |name, value| name.in?(names) && value.blank? }
      end
    end
  end
end
