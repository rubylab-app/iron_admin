# frozen_string_literal: true

module IronAdmin
  # Applies the related resource read policy and tenant scope to show-page panels.
  module RelatedRecordsHelper
    # Whether the current user may see this association panel.
    #
    # HABTM with no registered resource has no read policy, so the panel stays
    # visible. Every other panel requires the related resource to allow +:read+.
    #
    # @param assoc [Hash] association config; +:resource+ is nil when HABTM has none
    # @return [Boolean]
    def related_panel_readable?(assoc)
      resource = assoc[:resource]
      return true if resource.nil?

      resource.crud_allowed?(:read, iron_admin_current_user)
    end

    # Tenant-scoped records for a has_many or HABTM panel.
    #
    # @param record [Object] parent record that owns the association
    # @param assoc [Hash] association config with a +:name+ key
    # @return [Object] the association after IronAdmin::TenantScope.apply
    def related_records(record, assoc)
      IronAdmin::TenantScope.apply(record.public_send(assoc[:name]))
    end

    # Has-one record, or nil when it is missing or outside the tenant scope.
    #
    # Without a configured tenant scope the associated record is returned as-is
    # and no extra query runs. With a tenant scope, membership is checked through
    # the related resource adapter: the record is kept only when filtering
    # +TenantScope.apply(adapter.all)+ by its primary key finds a row.
    #
    # @param record [Object] parent record that owns the association
    # @param assoc [Hash] association config with +:name+ and +:resource+
    # @return [Object, nil]
    def related_record(record, assoc)
      related = record.public_send(assoc[:name])
      return if related.nil?
      return related unless IronAdmin::TenantScope.configured?

      adapter = assoc[:resource].adapter
      scoped = IronAdmin::TenantScope.apply(adapter.all)
      primary_key = adapter.primary_key
      found = adapter.filter(scoped, primary_key.to_sym, related.public_send(primary_key)).first
      found ? related : nil
    end
  end
end
