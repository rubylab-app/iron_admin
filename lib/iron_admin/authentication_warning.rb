# frozen_string_literal: true

module IronAdmin
  # Warns at boot when production runs with no +config.authenticate+ block.
  #
  # The engine cannot deny by itself in that case: protecting the mount with
  # a route constraint (Devise's +authenticate :user do ... end+) is a valid
  # setup that needs no block. So it says so once, at boot, in production.
  #
  # @api private
  module AuthenticationWarning
    # The logged message.
    MESSAGE = "[IronAdmin] config.authenticate is not set: the admin answers every request " \
              "unless its mount is protected by a route constraint. Set config.authenticate " \
              "in config/initializers/iron_admin.rb. See " \
              "https://github.com/rubylab-app/iron_admin/blob/main/docs/guides/authentication.md"

    # Logs {MESSAGE} when +env+ is production and no authenticate block is set.
    #
    # @param configuration [IronAdmin::Configuration]
    # @param env [ActiveSupport::EnvironmentInquirer]
    # @param logger [#warn, nil]
    # @return [Boolean] whether it warned
    def self.call(configuration: IronAdmin.configuration, env: Rails.env, logger: Rails.logger)
      return false unless env.production? && configuration.authenticate_block.nil?

      logger&.warn(MESSAGE)
      true
    end
  end
end
