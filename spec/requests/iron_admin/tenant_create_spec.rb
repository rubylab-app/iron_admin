# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenant assignment on admin create", type: :request do
  let(:tenant) { create(:user) }

  let(:resource) do
    Class.new(IronAdmin::Resource) do
      def self.name = "TenantLicenseResource"
      def self.resource_name = "tenant_licenses"

      self.model_class_override = License

      belongs_to :user, display: :email
      form_fields :license_key, :license_type, :max_devices, :user
    end
  end

  before do
    captured_tenant = tenant
    IronAdmin.configure do |config|
      config.tenant_scope do |scope|
        scope.model == License ? scope.where(user_id: captured_tenant.id) : scope
      end
    end
    IronAdmin::ResourceRegistry.register(resource)
  end

  it "saves the tenant on the created license and shows that record" do
    post iron_admin.resources_path("tenant_licenses"),
         params: { record: { license_key: "TEN-001", license_type: "pro", max_devices: 2 } }

    license = License.find_by!(license_key: "TEN-001")

    expect(license.user_id).to eq(tenant.id)
    expect(response).to redirect_to(iron_admin.resource_path("tenant_licenses", license))

    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it "renders the new form for a record built inside the tenant scope" do
    get iron_admin.new_resource_path("tenant_licenses")

    expect(response).to have_http_status(:ok)

    document = response.parsed_body
    selected_values = document.css("select[name='record[user_id]'] option[selected]").pluck("value")

    expect(selected_values).to include(tenant.id.to_s)
  end
end
