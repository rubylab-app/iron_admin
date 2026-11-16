# frozen_string_literal: true

module IronAdmin
  # Logs when a resource's {IronAdmin::Resource.field} overrides match no inferred field.
  module FieldOverrideWarning
    # Warns in development and test, once per distinct set of unresolved overrides.
    #
    # Each resource with unresolved names produces one warning line. The warning
    # repeats only when the set of resource names and unresolved field names
    # changes. A resource whose fields cannot be resolved is skipped.
    #
    # @param resources [Enumerable] registry entries, default {ResourceRegistry.all}
    # @param env [#development?, #test?]
    # @param logger [#warn]
    # @return [Boolean] whether any warning was logged
    def self.call(resources: ResourceRegistry.all, env: Rails.env, logger: Rails.logger)
      return false unless env.development? || env.test?

      signature = unresolved_signature(resources)
      return false if signature == @reported_signature

      @reported_signature = signature
      log_warnings(signature, logger)
      signature.any?
    end

    # Forgets the set of overrides reported by the previous {.call}.
    #
    # @return [void]
    def self.reset!
      @reported_signature = nil
    end

    def self.unresolved_signature(resources)
      entries = resources.filter_map { |resource| unresolved_entry(resource) }
      entries.sort
    end

    def self.unresolved_entry(resource)
      names = resource.unresolved_field_overrides
      return if names.empty?

      [resource.name.to_s, names]
    rescue StandardError
      nil
    end

    def self.log_warnings(signature, logger)
      signature.each do |resource_name, names|
        logger.warn(warning_message(resource_name, names))
      end
    end

    def self.warning_message(resource_name, names)
      details = names.map { |name| warning_clause(name) }.join(" ")
      "[IronAdmin] #{resource_name}: #{details}"
    end

    def self.warning_clause(name)
      clause = "field :#{name} matches no field, so its options are ignored."
      return clause unless name.to_s.end_with?("_id")

      "#{clause} Foreign keys of belongs_to associations are configured under the association name."
    end
    private_class_method :unresolved_signature, :unresolved_entry, :log_warnings, :warning_message, :warning_clause
  end
end
