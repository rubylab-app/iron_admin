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
          ip_address: request.remote_ip,
          tenant_key: iron_admin_audit_tenant_key
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

      # The record's saved changes, with concealed fields and the host app's
      # filter_parameters replaced by "[FILTERED]".
      #
      # @param record [Object]
      # @return [Hash]
      def audited_changes(record)
        audit_parameter_filter.filter(@resource_class.adapter.record_changes(record).to_h)
      end

      # Built once per request: bulk actions and imports emit one event per
      # record, and resolving the resource's fields for each would repeat the
      # same work for every row. The filter is built from a single
      # +resolved_fields+ call.
      #
      # @return [ActiveSupport::ParameterFilter]
      def audit_parameter_filter
        @audit_parameter_filter ||= begin
          fields = @resource_class.resolved_fields
          exact_names = concealed_names_for(fields).map { |name| /\A#{Regexp.escape(name)}\z/ }
          ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters + exact_names)
        end
      end

      # Names of fields declared with type :password.
      #
      # @return [Array<String>]
      def password_field_names
        password_names_for(@resource_class.resolved_fields)
      end

      # Password fields plus fields concealed from the current user.
      #
      # @return [Array<String>]
      def concealed_field_names
        concealed_names_for(@resource_class.resolved_fields)
      end

      # Names of the given fields declared with type :password.
      #
      # @param fields [Array<IronAdmin::Field>] Resolved resource fields
      # @return [Array<String>]
      def password_names_for(fields)
        fields.filter_map do |field|
          field.name.to_s if field.type == :password
        end
      end

      # Password names plus names concealed from the current user, from fields
      # the caller already resolved.
      #
      # @param fields [Array<IronAdmin::Field>] Resolved resource fields
      # @return [Array<String>]
      def concealed_names_for(fields)
        user = iron_admin_current_user
        concealed = fields.filter_map do |field|
          next if field.type == :password

          field.name.to_s if field.concealed_from?(user)
        end
        (password_names_for(fields) + concealed).uniq
      end
    end
  end
end
