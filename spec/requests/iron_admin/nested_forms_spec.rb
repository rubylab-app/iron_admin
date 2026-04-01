# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Nested Forms", type: :request do
  let(:nested_user_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name
        "NestedUserResource"
      end

      def self.resource_name
        "nested_users"
      end

      has_many :licenses, nested: true, allow_destroy: true
    end
  end

  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(nested_user_resource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
  end

  describe "POST create with nested attributes" do
    it "creates parent with nested children" do
      expect do
        post iron_admin.resources_path("nested_users"),
             params: {
               record: {
                 name: "Jane Doe",
                 email: "jane@example.com",
                 role: "admin",
                 licenses_attributes: {
                   "0" => { license_key: "KEY-NEW-001", license_type: "pro", max_devices: 5 },
                 },
               },
             },
             as: :html
      end.to change(User, :count).by(1).and change(License, :count).by(1)
    end

    it "associates nested records with the parent" do
      post iron_admin.resources_path("nested_users"),
           params: {
             record: {
               name: "Jane Doe",
               email: "jane@example.com",
               role: "admin",
               licenses_attributes: {
                 "0" => { license_key: "KEY-NEW-002", license_type: "standard", max_devices: 3 },
               },
             },
           },
           as: :html

      user = User.last
      expect(user.licenses.count).to eq(1)
      expect(user.licenses.first.license_key).to eq("KEY-NEW-002")
    end

    it "creates multiple nested records" do
      expect do
        post iron_admin.resources_path("nested_users"),
             params: {
               record: {
                 name: "Multi License User",
                 email: "multi@example.com",
                 role: "member",
                 licenses_attributes: {
                   "0" => { license_key: "KEY-MULTI-001", license_type: "pro", max_devices: 5 },
                   "1" => { license_key: "KEY-MULTI-002", license_type: "standard", max_devices: 3 },
                 },
               },
             },
             as: :html
      end.to change(License, :count).by(2)
    end
  end

  describe "PATCH update with nested attributes" do
    let(:user) { create(:user) }
    let!(:license) { create(:license, user: user) }

    it "updates existing nested records" do
      patch iron_admin.resource_path("nested_users", user),
            params: {
              record: {
                name: user.name,
                email: user.email,
                role: user.role,
                licenses_attributes: {
                  "0" => { id: license.id, license_type: "enterprise", max_devices: 100 },
                },
              },
            },
            as: :html

      expect(license.reload.license_type).to eq("enterprise")
      expect(license.reload.max_devices).to eq(100)
    end

    it "adds new nested records to existing parent" do
      expect do
        patch iron_admin.resource_path("nested_users", user),
              params: {
                record: {
                  name: user.name,
                  email: user.email,
                  role: user.role,
                  licenses_attributes: {
                    "0" => { id: license.id, license_type: license.license_type },
                    "1" => { license_key: "KEY-ADDED-001", license_type: "trial", max_devices: 1 },
                  },
                },
              },
              as: :html
      end.to change(License, :count).by(1)
    end

    it "destroys nested records when _destroy is set" do
      expect do
        patch iron_admin.resource_path("nested_users", user),
              params: {
                record: {
                  name: user.name,
                  email: user.email,
                  role: user.role,
                  licenses_attributes: {
                    "0" => { id: license.id, _destroy: "1" },
                  },
                },
              },
              as: :html
      end.to change(License, :count).by(-1)
    end

    context "when allow_destroy is false" do
      let(:no_destroy_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "NoDestroyNestedResource"
          end

          def self.resource_name
            "no_destroy_nested_users"
          end

          has_many :licenses, nested: true, allow_destroy: false
        end
      end

      before { IronAdmin::ResourceRegistry.register(no_destroy_resource) }

      it "does not permit _destroy in params" do
        expect do
          patch iron_admin.resource_path("no_destroy_nested_users", user),
                params: {
                  record: {
                    name: user.name,
                    email: user.email,
                    role: user.role,
                    licenses_attributes: {
                      "0" => { id: license.id, _destroy: "1" },
                    },
                  },
                },
                as: :html
        end.not_to change(License, :count)
      end
    end
  end

  describe "GET edit with nested form rendering" do
    let(:user) { create(:user) }

    before do
      create(:license, user: user, license_key: "EDIT-KEY-001")
    end

    it "renders the edit form with nested section" do
      get iron_admin.edit_resource_path("nested_users", user), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Licenses")
      expect(response.body).to include("EDIT-KEY-001")
    end

    it "renders the new form with empty nested section" do
      get iron_admin.new_resource_path("nested_users"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Licenses")
    end
  end

  describe "nested permits security" do
    let(:user) { create(:user) }

    it "permits id for nested record updates" do
      license = create(:license, user: user)

      patch iron_admin.resource_path("nested_users", user),
            params: {
              record: {
                name: user.name,
                email: user.email,
                role: user.role,
                licenses_attributes: {
                  "0" => { id: license.id, license_type: "updated" },
                },
              },
            },
            as: :html

      expect(license.reload.license_type).to eq("updated")
    end
  end
end
