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
      @action_options = action_options
      @resource_labels = resource_labels
      @resource_options = resource_options
    end

    private

    # Actions offered by the Action filter: every action logged so far,
    # custom resource actions included, plus the one currently selected.
    #
    # @api private
    # @return [Array<String>]
    def action_options
      (logged_values(:action) + [params[:action_filter]].grep(String)).compact_blank.uniq.sort
    end

    # Labels of the registered resources, keyed by the class name that audit
    # entries store. Stored values are only looked up here, never constantized.
    #
    # @api private
    # @return [Hash{String => String}]
    def resource_labels
      ResourceRegistry.all.to_h { |resource| [resource.name, resource.label] }
    end

    # Resources offered by the Resource filter: every registered resource, then
    # any other resource logged so far or currently selected, under its stored value.
    #
    # @api private
    # @return [Array<Array(String, String)>] Value and label pairs
    def resource_options
      others = (logged_values(:resource) + [params[:resource]].grep(String)).compact_blank.uniq.sort
      @resource_labels.to_a + (others - @resource_labels.keys).map { |name| [name, name] }
    end

    # @api private
    def logged_values(attribute)
      if AuditLog.database_storage_available?
        AuditEntry.distinct.pluck(attribute)
      else
        AuditLog.entries.map { |entry| entry.public_send(attribute).to_s }
      end
    end

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
