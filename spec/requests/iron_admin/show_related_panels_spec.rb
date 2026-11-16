# frozen_string_literal: true

require "rails_helper"

RSpec.describe "IronAdmin show related panels", type: :request do
  describe "read policy" do
    it "hides licenses when the licenses resource denies read" do
      user = create(:user)
      license = create(:license, user:, license_key: "HIDDEN-KEY-1")
      register_denied_related("licenses", License)

      get iron_admin.resource_path("users", user)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(iron_admin.resource_path("licenses", license))
    end

    it "shows licenses when the licenses resource allows read" do
      user = create(:user)
      license = create(:license, user:, license_key: "HIDDEN-KEY-1")

      get iron_admin.resource_path("users", user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(iron_admin.resource_path("licenses", license))
    end

    it "hides a profile when the profiles resource denies read" do
      user = create(:user)
      Profile.create!(user:, bio: "Secret bio text")
      register_denied_related("profiles", Profile)

      get iron_admin.resource_path("users", user)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Secret bio text")
    end
  end

  describe "tenant scope" do
    it "lists only licenses inside the tenant scope" do
      user = create(:user)
      pro_license = create(:license, user:, license_key: "PRO-KEY-1", license_type: "pro")
      standard_license = create(:license, user:, license_key: "STD-KEY-1", license_type: "standard")
      IronAdmin.configure do |config|
        config.tenant_scope do |scope|
          scope.model == License ? scope.where(license_type: "pro") : scope
        end
      end

      get iron_admin.resource_path("users", user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(iron_admin.resource_path("licenses", pro_license))
      expect(response.body).not_to include(iron_admin.resource_path("licenses", standard_license))
    end

    it "lists only tags inside the tenant scope" do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::TagResource)
      post_record = Post.create!(title: "Scoped post")
      post_record.tags << Tag.create!(name: "visible-tag")
      post_record.tags << Tag.create!(name: "other-tag")
      IronAdmin.configure do |config|
        config.tenant_scope do |scope|
          scope.model == Tag ? scope.where(name: "visible-tag") : scope
        end
      end

      get iron_admin.resource_path("posts", post_record)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("visible-tag")
      expect(response.body).not_to include("other-tag")
    end
  end

  def register_denied_related(resource_name, model)
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)

    resource = Class.new(IronAdmin::Resource)
    class_name = "Denied#{model.name}Resource"
    resource.define_singleton_method(:name) { class_name }
    resource.define_singleton_method(:resource_name) { resource_name }
    resource.model_class_override = model
    resource.class_eval { policy { deny :read } }
    IronAdmin::ResourceRegistry.register(resource)
  end
end
