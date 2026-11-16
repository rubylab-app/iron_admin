# frozen_string_literal: true

require "rails_helper"

RSpec.describe "belongs_to foreign key field overrides", type: :request do
  let(:owner) { create(:user) }
  let(:license) { create(:license, user: owner, status: :active) }

  def register_license_resource(class_name, resource_name, &block)
    resource = Class.new(IronAdmin::Resource)
    resource.class_eval do
      define_singleton_method(:name) { class_name }
      define_singleton_method(:resource_name) { resource_name }
      self.model_class_override = License
    end
    resource.class_eval(&block)
    IronAdmin::ResourceRegistry.register(resource)
  end

  describe "field :user_id, readonly: true" do
    let(:resource_name) { "fk_readonly_licenses" }

    before do
      register_license_resource("FkReadonlyLicenseResource", resource_name) do
        belongs_to :user, display: :email
        field :user_id, readonly: true
      end
    end

    it "omits the user input and does not reassign the license" do
      other_user = create(:user)

      get iron_admin.edit_resource_path(resource_name, license)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("name=\"record[user_id]\"")

      patch iron_admin.resource_path(resource_name, license),
            params: { record: { user_id: other_user.id, license_type: "pro" } }
      license.reload

      expect(license.user_id).to eq(owner.id)
      expect(license.license_type).to eq("pro")
    end
  end

  describe "field :user_id, visible: false" do
    let(:resource_name) { "fk_hidden_licenses" }

    before do
      register_license_resource("FkHiddenLicenseResource", resource_name) do
        belongs_to :user, display: :email
        field :user_id, visible: false
      end
    end

    it "hides the associated email on the show page" do
      get iron_admin.resource_path(resource_name, license)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(owner.email)
    end
  end

  describe "field :user overriding field :user_id" do
    let(:resource_name) { "fk_named_licenses" }

    before do
      register_license_resource("FkNamedLicenseResource", resource_name) do
        belongs_to :user, display: :email
        field :user, visible: true
        field :user_id, visible: false
      end
    end

    it "shows the associated email because the association name wins" do
      get iron_admin.resource_path(resource_name, license)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(owner.email)
    end
  end
end
