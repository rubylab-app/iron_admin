# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenant containment for in-list scopes", type: :request do
  let(:tenant_a) { create(:user) }
  let(:tenant_b) { create(:user) }
  let(:outsider) { create(:user) }

  let(:resource) do
    Class.new(IronAdmin::Resource) do
      def self.name = "ContainedLicenseResource"
      def self.resource_name = "contained_licenses"

      self.model_class_override = License

      belongs_to :user, display: :email
      form_fields :license_key, :license_type, :max_devices, :user
    end
  end

  before do
    allowed_ids = [tenant_a.id, tenant_b.id]
    IronAdmin.configure do |config|
      config.tenant_scope do |scope|
        scope.model == License ? scope.where(user_id: allowed_ids) : scope
      end
    end
    IronAdmin::ResourceRegistry.register(resource)
  end

  it "rejects a create that posts a user outside the tenant list" do
    post iron_admin.resources_path("contained_licenses"),
         params: { record: { license_key: "OUT-1", license_type: "pro", max_devices: 1, user_id: outsider.id } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(License.find_by(license_key: "OUT-1")).to be_nil
  end

  it "creates a license for a user inside the tenant list" do
    post iron_admin.resources_path("contained_licenses"),
         params: { record: { license_key: "IN-1", license_type: "pro", max_devices: 1, user_id: tenant_b.id } }

    license = License.find_by!(license_key: "IN-1")

    expect(license.user_id).to eq(tenant_b.id)
    expect(response).to redirect_to(iron_admin.resource_path("contained_licenses", license))
  end

  it "rejects an update that moves a license outside the tenant list" do
    license = create(:license, user: tenant_a, license_key: "MOVE-1")

    patch iron_admin.resource_path("contained_licenses", license),
          params: { record: { user_id: outsider.id } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(license.reload.user_id).to eq(tenant_a.id)
  end
end
