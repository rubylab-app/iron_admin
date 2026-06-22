require "rails_helper"
require_relative "../../support/test_resources"

RSpec.describe "IronAdmin::Search", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  describe "GET /search" do
    it "returns matching results" do
      create(:user, name: "John Doe", email: "john@example.com")
      create(:user, name: "Jane Smith", email: "jane@example.com")

      get iron_admin.search_path(q: "John")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("John Doe")
      expect(response.body).not_to include("Jane Smith")
    end

    it "returns empty when no query" do
      get iron_admin.search_path
      expect(response).to have_http_status(:ok)
    end

    it "applies tenant scope to global search results" do
      create(:user, name: "In Tenant", email: "visible@example.com", active: true)
      create(:user, name: "Out Of Tenant", email: "hidden@example.com", active: false)

      IronAdmin.configure do |config|
        config.tenant_scope do |scope|
          scope.where(active: true)
        end
      end

      get iron_admin.search_path(q: "example.com")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("In Tenant")
      expect(response.body).not_to include("Out Of Tenant")
    end

    it "applies tenant scope independently across searched resources" do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)

      visible_user = create(:user, name: "Tenant Shared", email: "shared-visible@example.com", active: true)
      hidden_user = create(:user, name: "Tenant Shared Hidden", email: "shared-hidden@example.com", active: false)
      visible_license = create(:license, user: visible_user, license_key: "TENANT-SHARED-VISIBLE")
      hidden_license = create(:license, user: hidden_user, license_key: "TENANT-SHARED-HIDDEN")

      IronAdmin.configure do |config|
        config.tenant_scope do |scope|
          if scope.klass == User
            scope.where(active: true)
          else
            scope.joins(:user).where(users: { active: true })
          end
        end
      end

      get iron_admin.search_path(q: "Shared")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tenant Shared")
      expect(response.body).to include(iron_admin.resource_path("licenses", visible_license))
      expect(response.body).not_to include("Tenant Shared Hidden")
      expect(response.body).not_to include(iron_admin.resource_path("licenses", hidden_license))
    end
  end
end
