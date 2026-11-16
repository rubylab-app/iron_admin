# frozen_string_literal: true

require "rails_helper"

RSpec.describe "nested tenant rows", type: :request do
  before(:all) do
    ActiveRecord::Base.connection.create_table :nest_owners, force: true do |t|
      t.string :name
      t.timestamps
    end
    ActiveRecord::Base.connection.create_table :nest_details, force: true do |t|
      t.integer :nest_owner_id
      t.integer :tag_id
      t.string :label
      t.timestamps
    end
    ActiveRecord::Base.connection.create_table :nest_items, force: true do |t|
      t.integer :nest_owner_id
      t.string :label
      t.timestamps
    end

    Object.const_set(:NestDetail, Class.new(ApplicationRecord) do
      self.table_name = "nest_details"
      belongs_to :nest_owner
      belongs_to :tag, optional: true
    end)
    Object.const_set(:NestItem, Class.new(ApplicationRecord) do
      self.table_name = "nest_items"
      belongs_to :nest_owner
    end)
    Object.const_set(:NestOwner, Class.new(ApplicationRecord) do
      self.table_name = "nest_owners"
      has_one :nest_detail
      has_many :nest_items
      accepts_nested_attributes_for :nest_detail, :nest_items
    end)
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :nest_items, if_exists: true
    ActiveRecord::Base.connection.drop_table :nest_details, if_exists: true
    ActiveRecord::Base.connection.drop_table :nest_owners, if_exists: true
    Object.send(:remove_const, :NestOwner) if defined?(NestOwner)
    Object.send(:remove_const, :NestDetail) if defined?(NestDetail)
    Object.send(:remove_const, :NestItem) if defined?(NestItem)
  end

  let(:nest_owner_resource) do
    Class.new(IronAdmin::Resource) do
      def self.name = "NestOwnerResource"
      def self.resource_name = "nest_owners"

      self.model_class_override = NestOwner
      has_one :nest_detail, nested: true
      has_many :nest_items, nested: true
    end
  end

  before { IronAdmin::ResourceRegistry.register(nest_owner_resource) }

  it "stamps a new has_one row with the tenant value" do
    scope_nested_labels_to_tenant

    expect do
      post iron_admin.resources_path("nest_owners"), params: {
        record: { name: "Scoped owner", nest_detail_attributes: { label: "x" } },
      }
    end.to change(NestDetail, :count).by(1)

    expect(NestOwner.find_by!(name: "Scoped owner").nest_detail.label).to eq("tenant")
  end

  it "leaves an existing nested row on its tenant column" do
    scope_nested_labels_to_tenant
    owner = NestOwner.create!(name: "Kept owner")
    item = owner.nest_items.create!(label: "tenant")

    patch iron_admin.resource_path("nest_owners", owner), params: {
      record: { name: owner.name, nest_items_attributes: { "0" => { id: item.id, label: "other" } } },
    }

    expect(response).to have_http_status(:redirect)
    expect(item.reload.label).to eq("tenant")
  end

  it "rejects a has_one foreign key outside the tenant" do
    visible = Tag.create!(name: "visible-tag")
    other = Tag.create!(name: "other-tag")
    owner = NestOwner.create!(name: "Tagged owner")
    detail = owner.create_nest_detail!(label: "kept", tag: visible)
    scope_tags_to_visible

    patch iron_admin.resource_path("nest_owners", owner), params: {
      record: { name: owner.name, nest_detail_attributes: { id: detail.id, tag_id: other.id } },
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(detail.reload.tag_id).to eq(visible.id)
  end

  def scope_nested_labels_to_tenant
    IronAdmin.configure do |config|
      config.tenant_scope do |scope|
        [NestDetail, NestItem].include?(scope.model) ? scope.where(label: "tenant") : scope
      end
    end
  end

  def scope_tags_to_visible
    IronAdmin.configure do |config|
      config.tenant_scope { |scope| scope.model == Tag ? scope.where(name: "visible-tag") : scope }
    end
  end
end
