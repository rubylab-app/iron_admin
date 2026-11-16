# frozen_string_literal: true

require "rails_helper"

RSpec.describe "config.audit_tenant", type: :request do
  let(:tenant) { { key: "1" } }

  def log_entry(tenant_key:, name:, resource: "UserResource", action: "update")
    IronAdmin::AuditEntry.create!(user_identifier: "7", action: action, resource: resource, record_id: 1,
                                  record_changes: { "name" => ["Before", name] }, ip_address: "127.0.0.1",
                                  tenant_key: tenant_key)
  end

  before do
    current = tenant
    IronAdmin.configure do |config|
      config.audit_enabled = true
      config.audit_storage = :database
      config.audit_tenant { |_controller| current[:key] }
    end
    IronAdmin::AuditEntry.delete_all
  end

  after { IronAdmin::AuditEntry.delete_all }

  it "records the current tenant on each change made in the admin" do
    post iron_admin.resources_path("users"), params: { record: { name: "Ana", email: "ana@example.com" } }

    expect(IronAdmin::AuditEntry.last.tenant_key).to eq("1")
  end

  it "lists only the current tenant's entries" do
    log_entry(tenant_key: "1", name: "Own Tenant Change")
    log_entry(tenant_key: "2", name: "Other Tenant Change")

    get iron_admin.audit_path

    expect(response.body).to include("Own Tenant Change")
    expect(response.body).not_to include("Other Tenant Change")
  end

  it "hides entries that carry no tenant" do
    log_entry(tenant_key: nil, name: "Untenanted Change")

    get iron_admin.audit_path

    expect(response.body).not_to include("Untenanted Change")
  end

  it "lists nothing when the request has no tenant" do
    tenant[:key] = nil
    log_entry(tenant_key: nil, name: "Untenanted Change")
    log_entry(tenant_key: "2", name: "Other Tenant Change")

    get iron_admin.audit_path

    expect(response.body).not_to include("Untenanted Change")
    expect(response.body).not_to include("Other Tenant Change")
  end

  it "offers only the current tenant's resources in the Resource filter" do
    log_entry(tenant_key: "1", name: "Own", resource: "OwnTenantResource")
    log_entry(tenant_key: "2", name: "Other", resource: "OtherTenantResource")

    get iron_admin.audit_path

    options = response.parsed_body.css("select[name='resource'] option").pluck("value")
    expect(options).to include("OwnTenantResource")
    expect(options).not_to include("OtherTenantResource")
  end

  it "offers only the current tenant's actions in the Action filter" do
    log_entry(tenant_key: "1", name: "Own", action: "own_tenant_action")
    log_entry(tenant_key: "2", name: "Other", action: "other_tenant_action")

    get iron_admin.audit_path

    options = response.parsed_body.css("select[name='action_filter'] option").pluck("value")
    expect(options).to include("own_tenant_action")
    expect(options).not_to include("other_tenant_action")
  end

  context "with memory storage" do
    before { IronAdmin.configuration.audit_storage = :memory }

    it "lists only the current tenant's entries" do
      post iron_admin.resources_path("users"), params: { record: { name: "Ana", email: "ana@example.com" } }
      tenant[:key] = "2"
      post iron_admin.resources_path("users"), params: { record: { name: "Bob", email: "bob@example.com" } }

      get iron_admin.audit_path

      expect(response.body).to include("Bob")
      expect(response.body).not_to include("Ana")
    end
  end

  it "logs an event built without tenant_key" do
    IronAdmin::AuditLog.log(Struct.new(:user, :action, :resource, :record_id, :changes, :ip_address)
                                  .new(nil, :create, "UserResource", 1, {}, "127.0.0.1"))

    expect(IronAdmin::AuditEntry.last.tenant_key).to be_nil
  end

  it "raises a configuration error when the table has no tenant_key column" do
    allow(IronAdmin::AuditEntry).to receive(:column_names).and_return(IronAdmin::AuditEntry.column_names - ["tenant_key"])

    expect { IronAdmin::AuditLog.query(tenant_key: "1") }.to raise_error(IronAdmin::ConfigurationError, /tenant_key column/)
  end
end
