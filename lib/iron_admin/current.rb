# frozen_string_literal: true

require "active_support/current_attributes"

module IronAdmin
  # Per-request state of the admin panel. Rails resets it around every request.
  #
  # @see IronAdmin.current_theme
  class Current < ActiveSupport::CurrentAttributes
    # @!attribute [rw] theme
    #   @return [IronAdmin::Configuration::Theme, nil] Theme resolved for the current request
    attribute :theme
  end
end
