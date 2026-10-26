# frozen_string_literal: true

module IronAdmin
  # Audit logging system for tracking admin panel actions.
  #
  # The AuditLog provides built-in tracking of create, update, and delete
  # operations performed through the admin panel. It supports two storage
  # backends: in-memory (default) and database.
  #
  # == Enabling Audit Logging
  #
  # Enable in your initializer:
  #
  #   IronAdmin.configure do |config|
  #     config.audit_enabled = true
  #     config.audit_storage = :database  # or :memory
  #   end
  #
  # For database storage, run the generator:
  #
  #   rails generate iron_admin:install_audit
  #   rails db:migrate
  #
  # == Viewing Audit Logs
  #
  # When enabled, audit logs are viewable at /admin/audit.
  #
  # @example Query recent audit entries
  #   entries = IronAdmin::AuditLog.query(resource: "IronAdmin::Resources::UserResource", action: :update)
  #   entries.each do |entry|
  #     puts "#{entry.user} updated user #{entry.record_id}"
  #   end
  #
  # @see IronAdmin::Configuration#audit_enabled
  # @see IronAdmin::Configuration#audit_storage
  class AuditLog
    # Represents a single audit log entry.
    #
    # Contains details about who performed what action on which record.
    class Entry
      # @return [Object] The user who performed the action
      attr_accessor :user

      # @return [Symbol] The action type (:create, :update, :delete)
      attr_accessor :action

      # @return [String] The resource name (e.g., "users")
      attr_accessor :resource

      # @return [Integer, String] The ID of the affected record
      attr_accessor :record_id

      # @return [Hash] The attribute changes (for updates)
      attr_accessor :changes

      # @return [String] The IP address of the request
      attr_accessor :ip_address

      # @return [Time] When the action occurred
      attr_accessor :timestamp

      # Creates a new audit entry.
      #
      # @param attrs [Hash] Entry attributes
      # @option attrs [Object] :user The user who performed the action
      # @option attrs [Symbol] :action The action type
      # @option attrs [String] :resource The resource name
      # @option attrs [Integer, String] :record_id The record ID
      # @option attrs [Hash] :changes The attribute changes
      # @option attrs [String] :ip_address The request IP
      # @option attrs [Time] :timestamp When it occurred (defaults to now)
      def initialize(attrs = {})
        attrs.each { |k, v| send("#{k}=", v) }
        @timestamp ||= Time.current
      end

      # The attribute changes, matching {AuditEntry#record_changes}.
      #
      # @return [Hash]
      def record_changes
        changes
      end

      # Converts the entry to a hash.
      #
      # @return [Hash] Entry attributes as a hash
      def to_h
        {
          user: user,
          action: action,
          resource: resource,
          record_id: record_id,
          changes: changes,
          ip_address: ip_address,
          timestamp: timestamp,
        }
      end
    end

    class << self
      # Returns all in-memory audit entries.
      #
      # @return [Array<Entry>] In-memory entries
      def entries
        @entries ||= []
      end

      # Logs an audit event.
      #
      # Automatically routes to the configured storage backend
      # (memory or database).
      #
      # @param event [Object] An event object with user, action, resource,
      #   record_id, changes, and ip_address attributes
      # @return [Entry, AuditEntry, nil] The created entry, or nil if disabled
      def log(event)
        return unless IronAdmin.configuration.audit_enabled

        if database_storage_available?
          log_to_database(event)
        else
          log_to_memory(event)
        end
      end

      # Queries audit entries with optional filters.
      #
      # @param filters [Hash] Filter criteria
      # @option filters [String] :resource Filter by resource name
      # @option filters [Symbol, String] :action Filter by action type
      # @option filters [Integer, String] :record_id Filter by record ID
      # @option filters [Time, Date] :from Entries after this time
      # @option filters [Time, Date] :to Entries before this time
      #
      # @return [Array<Entry>, ActiveRecord::Relation] Matching entries
      #
      # @example Query by resource
      #   AuditLog.query(resource: "IronAdmin::Resources::UserResource")
      #
      # @example Query by date range
      #   AuditLog.query(from: 1.week.ago, to: Time.current)
      def query(filters = {})
        if database_storage_available?
          query_database(filters)
        else
          query_memory(filters)
        end
      end

      # Clears all audit entries.
      #
      # @api private
      # @return [void]
      def clear!
        @entries = []
        AuditEntry.delete_all if database_storage_available?
      end

      # Checks if database storage is configured and available.
      #
      # @return [Boolean] True if database storage can be used
      def database_storage_available?
        IronAdmin.configuration.audit_storage == :database &&
          defined?(AuditEntry) &&
          AuditEntry.table_exists?
      rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
        false
      end

      private

      def log_to_memory(event)
        entry = Entry.new(
          user: event.user,
          action: event.action,
          resource: event.resource,
          record_id: event.record_id,
          changes: event.changes,
          ip_address: event.ip_address
        )

        entries << entry
        entry
      end

      def log_to_database(event)
        AuditEntry.create!(
          user_identifier: event.user.respond_to?(:id) ? event.user.id.to_s : event.user.to_s,
          action: event.action.to_s,
          resource: event.resource.to_s,
          record_id: event.record_id,
          record_changes: event.changes,
          ip_address: event.ip_address
        )
      end

      def query_memory(filters)
        result = entries
        result = result.select { |e| e.resource == filters[:resource] } if filters[:resource]
        result = result.select { |e| e.timestamp >= filters[:from] } if filters[:from]
        result = result.select { |e| e.timestamp <= filters[:to] } if filters[:to]
        result = result.select { |e| e.action.to_s == filters[:action].to_s } if filters[:action]
        result = result.select { |e| e.record_id.to_s == filters[:record_id].to_s } if filters[:record_id]
        result
      end

      def query_database(filters)
        scope = AuditEntry.all
        scope = scope.by_resource(filters[:resource]) if filters[:resource]
        scope = scope.by_action(filters[:action]) if filters[:action]
        scope = scope.by_record_id(filters[:record_id]) if filters[:record_id]
        scope = scope.from_date(filters[:from]) if filters[:from]
        scope = scope.to_date(filters[:to]) if filters[:to]
        scope.order(created_at: :desc)
      end
    end
  end
end
