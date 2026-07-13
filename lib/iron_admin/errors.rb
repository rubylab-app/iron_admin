# frozen_string_literal: true

module IronAdmin
  # Base error class for all IronAdmin errors.
  class Error < StandardError; end

  # Raised when a record cannot be found by ID.
  # Adapter-agnostic replacement for ActiveRecord::RecordNotFound.
  class RecordNotFound < Error; end

  # Raised inside a transaction block to trigger a rollback.
  # Adapter-agnostic replacement for ActiveRecord::Rollback.
  class Rollback < Error; end

  # Raised when an adapter encounters an operational error
  # (network failure, invalid response, etc.).
  class AdapterError < Error; end

  # Raised for plugin registration/activation problems
  # (e.g. registering something that isn't a Plugin subclass).
  class PluginError < Error; end

  # Raised when a plugin declares an IronAdmin version requirement that the
  # running version does not satisfy.
  class IncompatiblePluginError < PluginError; end

  # Exception classes that mean the database is missing or unreachable
  # at boot time. Resolved lazily so the gem stays usable on
  # `--skip-active-record` hosts where `ActiveRecord` isn't loaded.
  #
  # @return [Array<Class>] Rescue classes for boot-time DB failures
  def self.db_unreachable_exceptions
    return [] unless defined?(ActiveRecord)

    [ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished]
  end
end
