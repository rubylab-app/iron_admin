# frozen_string_literal: true

module IronAdmin
  # Controller for viewing the audit log.
  #
  # Provides a filterable view of all admin panel actions when
  # audit logging is enabled.
  #
  # Access via /admin/audit
  #
  # @see IronAdmin::AuditLog
  # @see IronAdmin::Configuration#audit_enabled
  class AuditController < ApplicationController
    # Lists audit log entries with optional filters.
    #
    # Supports filtering by resource, action, and date range.
    #
    # @return [void]
    def index
      entries = filtered_entries
      # Database queries are already ordered newest first; memory entries are in log order.
      @entries = entries.is_a?(Array) ? entries.reverse : entries
      @filters_applied = params.values_at(:resource, :action_filter, :from, :to).any?(&:present?)
    end

    private

    # @api private
    def filtered_entries
      filters = {}
      filters[:resource] = params[:resource] if params[:resource].present?
      filters[:action] = params[:action_filter] if params[:action_filter].present?
      filters[:from] = parse_time(params[:from])
      filters[:to] = parse_time(params[:to])&.then { |time| date_only?(params[:to]) ? time.end_of_day : time }

      AuditLog.query(filters.compact)
    end

    # @api private
    def parse_time(value)
      Time.zone.parse(value.to_s) if value.present?
    rescue ArgumentError
      nil
    end

    # @api private
    def date_only?(value)
      value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    end
  end
end
