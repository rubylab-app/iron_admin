# frozen_string_literal: true

module IronAdmin
  module Generators
    # Generator for setting up database-backed audit logging.
    #
    # Creates the migration for the audit_entries table, which stores
    # a persistent log of all admin panel actions.
    #
    # @example Running the generator
    #   rails generate iron_admin:install_audit
    #   rails db:migrate
    #
    # @example Enabling database audit storage
    #   IronAdmin.configure do |config|
    #     config.audit_enabled = true
    #     config.audit_storage = :database
    #   end
    #
    # @see IronAdmin::AuditLog
    # @see IronAdmin::Configuration#audit_storage
    class InstallAuditGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      # Writes the audit entries migration into `db/migrate/`.
      #
      # We deliberately avoid `Rails::Generators::Migration#migration_template`
      # here: that helper goes through `ActiveRecord::Migration.current_version`
      # which opens a DB connection to read the schema cache. On a clean
      # machine (DB doesn't exist yet) or during a deploy where the DB
      # is briefly unreachable, that crashes the generator with
      # `ActiveRecord::ConnectionNotEstablished` and the migration file
      # never gets written. Using plain `template` plus a timestamp-based
      # filename keeps the generator DB-free, so `bin/rails db:create
      # db:migrate` (the natural bootstrap order) Just Works.
      #
      # @return [void]
      def create_migration
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        target = "db/migrate/#{timestamp}_create_iron_admin_audit_entries.rb"
        if existing_audit_migration?
          say_status :skip, "create_iron_admin_audit_entries migration already exists", :yellow
          return
        end
        template "create_iron_admin_audit_entries.rb.tt", target
      end

      private

      # @return [Boolean] True if a migration whose name ends with
      #   `_create_iron_admin_audit_entries.rb` is already present in
      #   `db/migrate/`. Avoids creating duplicate migrations on rerun.
      def existing_audit_migration?
        Dir.glob(File.join(destination_root, "db/migrate", "*_create_iron_admin_audit_entries.rb")).any?
      end
    end
  end
end
