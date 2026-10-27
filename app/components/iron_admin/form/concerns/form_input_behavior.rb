# frozen_string_literal: true

module IronAdmin
  module Form
    # Concerns for form component behavior.
    module Concerns
      # Shared behavior for form input components.
      #
      # Provides field-level readonly checks and theme access.
      # Included by all form input components.
      module FormInputBehavior
        extend ActiveSupport::Concern

        included do
          # @return [IronAdmin::Field, nil] Field configuration
          attr_reader :field

          # @return [Object, nil] Current user for readonly checks
          attr_reader :current_user

          # @return [Boolean] Whether input is explicitly disabled
          attr_reader :disabled
        end

        # Checks if input should be disabled (explicitly or via field readonly).
        #
        # @return [Boolean] True if input should be disabled
        def effectively_disabled?
          disabled || field_readonly?
        end

        # Checks if field is readonly for the current user.
        #
        # @return [Boolean] True if field is readonly
        def field_readonly?
          @field&.readonly?(@current_user) || false
        end

        # Returns the theme configuration.
        #
        # @return [IronAdmin::Configuration::Theme]
        def theme
          IronAdmin.current_theme
        end
      end
    end
  end
end
