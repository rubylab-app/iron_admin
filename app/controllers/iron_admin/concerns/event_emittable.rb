# frozen_string_literal: true

require "ostruct"

module IronAdmin
  module Concerns
    # Builds the event for each resource change, records it in the audit log
    # and passes it to the on_action callback.
    #
    # Expects @resource_class to hold the resource being changed.
    module EventEmittable
      extend ActiveSupport::Concern

      private

      # @param action [Symbol, String] The action performed
      # @param record [Object] The affected record
      # @return [void]
      def emit_event(action, record)
        event = OpenStruct.new(
          user: iron_admin_current_user,
          action: action,
          resource: @resource_class.name,
          record_id: record.id.to_s,
          changes: audited_changes(record),
          ip_address: request.remote_ip
        )

        IronAdmin::AuditLog.log(event)
        IronAdmin.configuration.on_action_block&.call(event)
      end

      # Emits the event once the resource's transaction commits, so a change
      # that rolls back is neither logged nor passed to on_action. Without an
      # open transaction, or with an adapter that has none, it emits at once.
      #
      # @param action [Symbol, String] The action performed
      # @param record [Object] The affected record
      # @return [void]
      def emit_event_after_commit(action, record)
        @resource_class.adapter.after_commit { emit_event(action, record) }
      end

      # The record's saved changes, with password fields and the host app's
      # filter_parameters replaced by "[FILTERED]".
      #
      # @param record [Object]
      # @return [Hash]
      def audited_changes(record)
        audit_parameter_filter.filter(@resource_class.adapter.record_changes(record).to_h)
      end

      # Built once per request: bulk actions and imports emit one event per
      # record, and resolving the resource's fields for each would repeat the
      # same work for every row.
      #
      # @return [ActiveSupport::ParameterFilter]
      def audit_parameter_filter
        @audit_parameter_filter ||= begin
          exact_passwords = password_field_names.map { |name| /\A#{Regexp.escape(name)}\z/ }
          ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters + exact_passwords)
        end
      end

      # @return [Array<String>] Names of the resource's password fields
      def password_field_names
        @resource_class.resolved_fields.select { |field| field.type == :password }.map { |field| field.name.to_s }
      end
    end
  end
end
