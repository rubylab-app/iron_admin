# frozen_string_literal: true

require "active_support/current_attributes"

module IronAdmin
  # Per-request state of the admin panel. Rails resets it around every request.
  #
  # This is not named Current. Resource files are written inside
  # +module IronAdmin+, so a constant named Current there would hide the
  # host application's ::Current.
  #
  # @see IronAdmin.current_theme
  class RequestContext < ActiveSupport::CurrentAttributes
    # @!attribute [rw] theme
    #   @return [IronAdmin::Configuration::Theme, nil] Theme resolved for the current request
    attribute :theme
  end
end
