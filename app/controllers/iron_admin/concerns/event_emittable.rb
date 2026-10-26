# frozen_string_literal: true

require "ostruct"

module IronAdmin
  module Concerns
    # Builds the event for each resource change, records it in the audit log
    # and passes it to the on_action callback.
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

      # The record's saved changes, with password fields and the host app's
      # filter_parameters replaced by "[FILTERED]".
      #
      # @param record [Object]
      # @return [Hash]
      def audited_changes(record)
        exact_passwords = password_field_names.map { |name| /\A#{Regexp.escape(name)}\z/ }
        filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters + exact_passwords)
        filter.filter(adapter.record_changes(record).to_h)
      end

      # @return [Array<String>] Names of the resource's password fields
      def password_field_names
        @resource_class.resolved_fields.select { |field| field.type == :password }.map { |field| field.name.to_s }
      end
    end
  end
end
