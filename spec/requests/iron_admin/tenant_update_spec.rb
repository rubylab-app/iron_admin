# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tenant columns on admin write", type: :request do
  describe "updating a license" do
    let(:tenant) { create(:user) }

    let(:resource) do
      Class.new(IronAdmin::Resource) do
        def self.name = "TenantUpdateLicenseResource"
        def self.resource_name = "tenant_update_licenses"

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

    it "keeps the tenant when the form posts another user id" do
      other = create(:user)
      license = create(:license, user: tenant, license_key: "OLD-KEY")

      patch iron_admin.resource_path("tenant_update_licenses", license), params: {
        record: { license_key: "NEW-KEY", user_id: other.id },
      }

      expect(response).to redirect_to(iron_admin.resource_path("tenant_update_licenses", license))
      license.reload
      expect(license.user_id).to eq(tenant.id)
      expect(license.license_key).to eq("NEW-KEY")
    end
  end

  describe "nested creates" do
    before(:all) do
      ActiveRecord::Base.connection.create_table :nest_parents, force: true do |t|
        t.string :name
        t.timestamps
      end
      ActiveRecord::Base.connection.create_table :nest_children, force: true do |t|
        t.integer :nest_parent_id
        t.integer :tag_id
        t.string :label
        t.timestamps
      end

      Object.const_set(:NestChild, Class.new(ApplicationRecord) do
        self.table_name = "nest_children"
        belongs_to :nest_parent
        belongs_to :tag, optional: true
      end)
      Object.const_set(:NestParent, Class.new(ApplicationRecord) do
        self.table_name = "nest_parents"
        has_many :nest_children
        accepts_nested_attributes_for :nest_children, allow_destroy: true
      end)
    end

    after(:all) do
      ActiveRecord::Base.connection.drop_table :nest_children, if_exists: true
      ActiveRecord::Base.connection.drop_table :nest_parents, if_exists: true
      Object.send(:remove_const, :NestChild) if defined?(NestChild)
      Object.send(:remove_const, :NestParent) if defined?(NestParent)
    end

    before do
      register_tenant_nest_parent_resource
      IronAdmin.configure do |config|
        config.tenant_scope do |scope|
          scope.model == NestChild ? scope.where(label: "tenant") : scope
        end
      end
    end

    it "saves a new nested child with the tenant equality" do
      post iron_admin.resources_path("nest_parents"), params: {
        record: { name: "Scoped parent", nest_children_attributes: { "0" => { label: "x" } } },
      }

      expect(response).to have_http_status(:redirect)
      expect(NestChild.count).to eq(1)
      expect(NestChild.order(:id).last.label).to eq("tenant")
    end
  end

  def register_tenant_nest_parent_resource
    resource = Class.new(IronAdmin::Resource) do
      def self.name = "TenantNestParentResource"
      def self.resource_name = "nest_parents"

      self.model_class_override = NestParent
      has_many :nest_children, nested: true
    end
    IronAdmin::ResourceRegistry.register(resource)
  end
end
