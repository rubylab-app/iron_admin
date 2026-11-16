# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Import::Importer do
  describe "IronAdmin::Import::Importer tenant assignment" do
    let(:tenant) { create(:user) }

    let(:resource) do
      Class.new(IronAdmin::Resource) do
        def self.name = "TenantLicenseResource"
        def self.resource_name = "tenant_licenses"

        self.model_class_override = License

        imports :csv
        import_fields :license_key, :license_type, :max_devices
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

    it "builds created rows inside the tenant scope" do
      file = StringIO.new("License key,License type,Max devices\nIMP-1,pro,2\n")
      result = described_class.new(resource, file: file, format: :csv).execute!

      license = License.find_by!(license_key: "IMP-1")

      expect(license.user_id).to eq(tenant.id)
      expect(result.created_count).to eq(1)
    end
  end
end
