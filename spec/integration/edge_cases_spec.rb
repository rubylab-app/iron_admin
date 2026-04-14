# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Edge Cases", type: :request do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  describe "empty data handling" do
    it "handles index with no records" do
      get iron_admin.resources_path("users")

      expect(response).to have_http_status(:ok)
    end

    it "handles search with no results" do
      get iron_admin.resources_path("users"), params: { q: "nonexistent" }

      expect(response).to have_http_status(:ok)
    end

    it "handles export with no records" do
      get iron_admin.export_path("users"), params: { format: :csv }

      expect(response).to have_http_status(:ok)
      # Should have header but no data rows
      lines = response.body.lines
      expect(lines.length).to eq(1) # Just header
    end
  end

  describe "invalid record handling" do
    it "raises error for non-existent record on show" do
      expect do
        get iron_admin.resource_path("users", 99_999)
      end.to raise_error(IronAdmin::RecordNotFound)
    end

    it "raises error for non-existent record on edit" do
      expect do
        get iron_admin.edit_resource_path("users", 99_999)
      end.to raise_error(IronAdmin::RecordNotFound)
    end

    it "raises error for non-existent record on update" do
      expect do
        patch iron_admin.resource_path("users", 99_999),
              params: { record: { name: "Test" } }
      end.to raise_error(IronAdmin::RecordNotFound)
    end

    it "raises error for non-existent record on destroy" do
      expect do
        delete iron_admin.resource_path("users", 99_999)
      end.to raise_error(IronAdmin::RecordNotFound)
    end
  end

  describe "unregistered resource handling" do
    it "returns 404 for unregistered resource" do
      get iron_admin.resources_path("nonexistent_resource")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "special character handling" do
    it "handles names with quotes" do
      post iron_admin.resources_path("users"),
           params: { record: { name: "O'Brien", email: "obrien@example.com", role: "user" } }

      follow_redirect!
      expect(response.body).to include("O&#39;Brien").or include("O'Brien")
    end

    it "handles emails with plus signs" do
      post iron_admin.resources_path("users"),
           params: { record: { name: "Test", email: "test+alias@example.com", role: "user" } }

      user = User.find_by(email: "test+alias@example.com")
      expect(user).to be_present
    end

    it "handles unicode in names" do
      post iron_admin.resources_path("users"),
           params: { record: { name: "日本語テスト", email: "unicode@example.com", role: "user" } }

      user = User.find_by(email: "unicode@example.com")
      expect(user.name).to eq("日本語テスト")
    end
  end

  describe "large data handling" do
    it "handles pagination with many records" do
      create_list(:user, 100)

      get iron_admin.resources_path("users")

      expect(response).to have_http_status(:ok)
      # Should show pagination
      expect(response.body).to include("page")
    end

    it "handles page parameter" do
      create_list(:user, 100)

      get iron_admin.resources_path("users"), params: { page: 2 }

      expect(response).to have_http_status(:ok)
    end

    it "handles invalid page parameter gracefully" do
      create_list(:user, 10)

      get iron_admin.resources_path("users"), params: { page: 999 }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "sorting edge cases" do
    before do
      create(:user, name: "Alice")
      create(:user, name: "Bob")
    end

    it "handles sorting with valid column" do
      get iron_admin.resources_path("users"),
          params: { sort: "name", direction: "asc" }

      expect(response).to have_http_status(:ok)
    end

    it "handles invalid sort column by using default" do
      get iron_admin.resources_path("users"),
          params: { sort: "nonexistent_column", direction: "asc" }

      expect(response).to have_http_status(:ok)
      # Should fall back to default sort without error
    end

    it "handles invalid sort direction by using default" do
      get iron_admin.resources_path("users"),
          params: { sort: "name", direction: "invalid" }

      expect(response).to have_http_status(:ok)
      # Should fall back to default direction without error
    end
  end

  describe "filter edge cases" do
    it "ignores empty filter values" do
      create_list(:user, 3)

      get iron_admin.resources_path("users"),
          params: { filters: { role: "" } }

      expect(response).to have_http_status(:ok)
    end

    it "handles missing filter params gracefully" do
      create(:user)

      get iron_admin.resources_path("users")

      expect(response).to have_http_status(:ok)
    end
  end

  describe "concurrent access" do
    it "handles concurrent updates gracefully" do
      user = create(:user, name: "Original")

      # Simulate two concurrent updates
      threads = 2.times.map do |i|
        Thread.new do
          patch iron_admin.resource_path("users", user),
                params: { record: { name: "Updated #{i}", email: user.email, role: user.role } }
        end
      end

      threads.each(&:join)

      user.reload
      expect(user.name).to match(/Updated \d/)
    end
  end
end
