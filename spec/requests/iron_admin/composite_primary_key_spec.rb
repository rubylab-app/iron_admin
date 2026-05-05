require "rails_helper"

RSpec.describe "IronAdmin composite primary key support", type: :request do
  let(:record) { Membership.create!(account_id: 7, scope_id: 13, role: "admin") }

  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::MembershipResource)
  end

  describe "GET /:resource_name" do
    it "returns success" do
      record
      get iron_admin.resources_path("memberships"), as: :html
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /:resource_name/:id" do
    it "loads the record using the composite primary key from the URL" do
      get iron_admin.resource_path("memberships", record.to_param), as: :html
      expect(response).to have_http_status(:ok)
    end

    it "raises IronAdmin::RecordNotFound when the composite key has the wrong number of segments" do
      expect do
        get iron_admin.resource_path("memberships", "7"), as: :html
      end.to raise_error(IronAdmin::RecordNotFound)
    end

    it "raises IronAdmin::RecordNotFound when no record matches" do
      expect do
        get iron_admin.resource_path("memberships", "99_99"), as: :html
      end.to raise_error(IronAdmin::RecordNotFound)
    end
  end

  describe "GET /:resource_name/:id/edit" do
    it "renders the edit form for a composite-PK record" do
      get iron_admin.edit_resource_path("memberships", record.to_param), as: :html
      expect(response).to have_http_status(:ok)
    end
  end
end

RSpec.describe "IronAdmin custom (single-column) primary key support", type: :request do
  let(:record) { SluggedResource.create!(slug: "hello-world", title: "Hello") }

  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::SluggedResourceResource)
  end

  describe "GET /:resource_name/:id" do
    it "loads the record using the custom primary key from the URL" do
      get iron_admin.resource_path("slugged_resources", record.to_param), as: :html
      expect(response).to have_http_status(:ok)
    end

    it "raises IronAdmin::RecordNotFound when no record matches" do
      expect do
        get iron_admin.resource_path("slugged_resources", "missing-slug"), as: :html
      end.to raise_error(IronAdmin::RecordNotFound)
    end
  end
end
