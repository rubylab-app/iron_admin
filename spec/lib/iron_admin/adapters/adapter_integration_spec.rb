# frozen_string_literal: true

require "rails_helper"
require_relative "../../../support/test_resources"

RSpec.describe "Adapter Integration", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
  end

  let(:adapter) { IronAdmin::Resources::UserResource.adapter }

  describe "Resource.adapter wiring" do
    it "returns an ActiveRecord adapter by default" do
      expect(adapter).to be_a(IronAdmin::Adapters::ActiveRecord)
    end

    it "wraps the correct model class" do
      expect(adapter.model_class).to eq(User)
    end

    it "memoizes the adapter instance" do
      expect(IronAdmin::Resources::UserResource.adapter).to be(adapter)
    end
  end

  describe "CRUD operations through adapter" do
    it "creates a record via adapter" do
      get iron_admin.new_resource_path("users"), as: :html
      expect(response).to have_http_status(:ok)

      post iron_admin.resources_path("users"),
           params: { record: { name: "Adapter User", email: "adapter@test.com" } },
           as: :html

      expect(response).to have_http_status(:redirect)
      expect(User.find_by(email: "adapter@test.com")).to be_present
    end

    it "reads a record via adapter" do
      user = create(:user, name: "Read Test")
      get iron_admin.resource_path("users", user), as: :html
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Read Test")
    end

    it "updates a record via adapter" do
      user = create(:user, name: "Old Name", email: "update@test.com")

      patch iron_admin.resource_path("users", user),
            params: { record: { name: "New Name", email: "update@test.com" } },
            as: :html

      expect(response).to have_http_status(:redirect)
      expect(user.reload.name).to eq("New Name")
    end

    it "destroys a record via adapter" do
      user = create(:user, name: "Delete Me")

      delete iron_admin.resource_path("users", user), as: :html

      expect(response).to have_http_status(:redirect)
      expect(User.find_by(id: user.id)).to be_nil
    end
  end

  describe "index with filtering through adapter" do
    it "filters records by enum column" do
      create(:user, name: "Admin User", role: "admin")
      create(:user, name: "Member User", role: "member")

      get iron_admin.resources_path("users"),
          params: { filters: { role: "admin" } },
          as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Admin User")
      expect(response.body).not_to include("Member User")
    end

    it "sorts records through adapter" do
      create(:user, name: "Zara")
      create(:user, name: "Alice")

      get iron_admin.resources_path("users"),
          params: { sort: "name", direction: "asc" },
          as: :html

      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body.index("Alice")).to be < body.index("Zara")
    end
  end

  describe "search through adapter" do
    it "searches across searchable columns via adapter" do
      create(:user, name: "Findable User", email: "find@test.com")
      create(:user, name: "Hidden User", email: "hidden@test.com")

      get iron_admin.resources_path("users"),
          params: { q: "Findable" },
          as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Findable User")
      expect(response.body).not_to include("Hidden User")
    end

    it "performs field-specific search via adapter" do
      create(:user, name: "John", email: "john@test.com")
      create(:user, name: "Jane", email: "jane@test.com")

      get iron_admin.resources_path("users"),
          params: { q: "email:john" },
          as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("john@test.com")
      expect(response.body).not_to include("jane@test.com")
    end
  end

  describe "global search through adapter" do
    it "searches all resources via adapter" do
      create(:user, name: "Global Search User", email: "global@test.com")

      get iron_admin.search_path, params: { q: "Global Search" }, as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Global Search User")
    end
  end

  describe "exports through adapter" do
    it "exports CSV via adapter" do
      create(:user, name: "Export User", email: "export@test.com")

      get iron_admin.export_path("users", format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("export@test.com")
    end

    it "exports JSON via adapter" do
      create(:user, name: "Export JSON", email: "json@test.com")

      get iron_admin.export_path("users", format: :json)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.first["email"]).to eq("json@test.com")
    end
  end

  describe "bulk actions through adapter" do
    it "filters by ids through adapter for bulk actions" do
      user1 = create(:user, name: "Bulk User 1")
      user2 = create(:user, name: "Bulk User 2")
      create(:user, name: "Not Selected")

      # Define a bulk action for testing
      IronAdmin::Resources::UserResource.bulk_action :test_bulk do |records|
        records.update_all(role: "bulk_updated")
      end

      post iron_admin.resource_bulk_action_path("users", "test_bulk"),
           params: { ids: [user1.id, user2.id] },
           as: :html

      expect(response).to have_http_status(:redirect)
      expect(user1.reload.role).to eq("bulk_updated")
      expect(user2.reload.role).to eq("bulk_updated")
    end
  end

  describe "adapter delegates to correct methods" do
    it "uses adapter.all for base_scope instead of model.all" do
      allow(adapter).to receive(:all).and_call_original

      get iron_admin.resources_path("users"), as: :html

      expect(response).to have_http_status(:ok)
      expect(adapter).to have_received(:all)
    end

    it "uses adapter.build for new records instead of model.new" do
      allow(adapter).to receive(:build).and_call_original

      get iron_admin.new_resource_path("users"), as: :html

      expect(response).to have_http_status(:ok)
      expect(adapter).to have_received(:build)
    end

    it "uses adapter.find_each for CSV export instead of scope.find_each" do
      create(:user, name: "Batch User", email: "batch@test.com")
      allow(adapter).to receive(:find_each).and_call_original

      get iron_admin.export_path("users", format: :csv)

      expect(response).to have_http_status(:ok)
      expect(adapter).to have_received(:find_each)
    end
  end

  describe "filter_options_for uses adapter" do
    it "uses adapter.enums for enum filter options" do
      license_adapter = IronAdmin::Resources::LicenseResource.adapter
      enums = license_adapter.enums
      expect(enums).to have_key("status")
    end

    it "uses adapter.distinct_values for non-enum filter options" do
      create(:user, role: "admin")
      create(:user, role: "member")
      values = adapter.distinct_values(:role)
      expect(values).to include("admin", "member")
    end
  end

  describe "BelongsToComponent uses adapter" do
    it "loads options through adapter" do
      create(:user, name: "Option User")
      component = IronAdmin::Form::BelongsToComponent.new(
        name: :user_id,
        association_class: User
      )
      options = component.options
      expect(options.flatten).to include("Option User")
    end

    it "counts records through adapter for search hint" do
      create_list(:user, 3)
      component = IronAdmin::Form::BelongsToComponent.new(
        name: :user_id,
        association_class: User,
        options_limit: 2
      )
      expect(component.show_search_hint?).to be true
    end
  end
end
