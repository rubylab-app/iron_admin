# frozen_string_literal: true

module IronAdmin
  # Lists, in development, the resources that have no +policy+ block while
  # {Configuration#default_policy} is +:allow+: every user the authenticate
  # block admits can run every action on them.
  #
  # The engine calls it after each load of the resources. It warns again only
  # when the list changes, so code reloads do not repeat it.
  #
  # @api private
  module PolicyCoverageWarning
    @last_warned = nil

    class << self
      # @param resources [Array<Class>] the registered resource classes
      # @param env [ActiveSupport::EnvironmentInquirer]
      # @param logger [#warn, nil]
      # @return [Boolean] whether it warned
      def call(resources: ResourceRegistry.all, env: Rails.env, logger: Rails.logger)
        return false unless env.development? && IronAdmin.configuration.default_allow?

        names = resources.reject(&:resource_policy).map(&:name).sort
        return false if names.empty? || names == @last_warned

        @last_warned = names
        logger&.warn(message(names))
        true
      end

      # Forgets the last list, so the next call warns again.
      # @return [void]
      def reset!
        @last_warned = nil
      end

      private

      def message(names)
        "[IronAdmin] These resources have no policy, so every user the authenticate block admits " \
          "can run every action on them: #{names.join(", ")}. Add a policy block to each, or set " \
          "config.default_policy = :deny to deny resources without one."
      end
    end
  end
end
