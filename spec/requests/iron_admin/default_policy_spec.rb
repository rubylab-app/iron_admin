# frozen_string_literal: true

require "rails_helper"

RSpec.describe "config.default_policy", type: :request do
  let(:user) { create(:user) }
  let(:license) { create(:license, user: user) }

  context "with :allow (the default)" do
    it "lets a resource without a policy list its records" do
      get iron_admin.resources_path("licenses"), as: :html

      expect(response).to have_http_status(:ok)
    end
  end

  context "with :deny" do
    before do
      IronAdmin.configure { |config| config.default_policy = :deny }
    end

    it "forbids the index of a resource without a policy" do
      get iron_admin.resources_path("licenses"), as: :html

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids a custom action of a resource without a policy" do
      post iron_admin.resource_action_path("licenses", license, "revoke"), as: :html

      expect(response).to have_http_status(:forbidden)
      expect(license.reload.status).not_to eq("revoked")
    end

    it "forbids a bulk action of a resource without a policy" do
      post iron_admin.resource_bulk_action_path("licenses", "export"), params: { ids: [license.id] }, as: :html

      expect(response).to have_http_status(:forbidden)
    end

    it "still applies a resource's own policy" do
      allowed = Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "ReadableUserResource"
        def self.resource_name = "readable_users"

        policy { allow :read }
      end
      IronAdmin::ResourceRegistry.register(allowed)

      get iron_admin.resources_path("readable_users"), as: :html

      expect(response).to have_http_status(:ok)
    end
  end
end
