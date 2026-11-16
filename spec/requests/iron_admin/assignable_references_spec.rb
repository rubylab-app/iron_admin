# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Assignable references on write", type: :request do
  describe "belongs_to" do
    before { register_ref_license_resource }

    it "rejects a create whose foreign key is outside the tenant" do
      create(:user, role: "admin")
      outsider = create(:user, role: "member")
      scope_users_to_admins

      expect do
        post iron_admin.resources_path("ref_licenses"), params: {
          record: license_attributes(build(:license), outsider.id),
        }
      end.not_to change(License, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates a record whose foreign key is inside the tenant" do
      admin = create(:user, role: "admin")
      create(:user, role: "member")
      scope_users_to_admins

      expect do
        post iron_admin.resources_path("ref_licenses"), params: {
          record: license_attributes(build(:license), admin.id),
        }
      end.to change(License, :count).by(1)
    end

    it "creates a record for any user when no tenant scope is configured" do
      outsider = create(:user, role: "member")

      expect do
        post iron_admin.resources_path("ref_licenses"), params: {
          record: license_attributes(build(:license), outsider.id),
        }
      end.to change(License, :count).by(1)
    end

    it "rejects an update that points at a user outside the tenant" do
      admin = create(:user, role: "admin")
      outsider = create(:user, role: "member")
      license = create(:license, user: admin)
      scope_users_to_admins

      patch iron_admin.resource_path("ref_licenses", license), params: {
        record: license_attributes(license, outsider.id),
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(license.reload.user_id).to eq(admin.id)
    end
  end

  describe "polymorphic belongs_to" do
    it "rejects a notable id outside the tenant" do
      create(:user, role: "admin")
      outsider = create(:user, role: "member")
      scope_users_to_admins

      expect do
        post iron_admin.resources_path("notes"), params: {
          record: { title: "N", body: "B", notable_type: "User", notable_id: outsider.id },
        }
      end.not_to change(Note, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates a note whose notable id is inside the tenant" do
      admin = create(:user, role: "admin")
      create(:user, role: "member")
      scope_users_to_admins

      expect do
        post iron_admin.resources_path("notes"), params: {
          record: { title: "N", body: "B", notable_type: "User", notable_id: admin.id },
        }
      end.to change(Note, :count).by(1)
    end

    it "rejects a type change that points the stored id outside the tenant" do
      admin = create(:user, role: "admin")
      note = Note.create!(title: "N", body: "B", notable_type: "User", notable_id: admin.id)
      scope_users_and_no_licenses

      patch iron_admin.resource_path("notes", note), params: {
        record: { title: "N", body: "B", notable_type: "License" },
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("is not available")
      expect(note.reload.notable_type).to eq("User")
    end

    it "clears an optional polymorphic notable when type and id are submitted blank" do
      admin = create(:user, role: "admin")
      create(:user, role: "member")
      note = Note.create!(title: "N", body: "B", notable_type: "User", notable_id: admin.id)
      scope_users_to_admins

      patch iron_admin.resource_path("notes", note), params: {
        record: { title: note.title, notable_type: "", notable_id: "" },
      }

      expect(response).to have_http_status(:redirect)
      expect(note.reload.notable).to be_nil
    end

    it "rejects a polymorphic type outside the allowlist when the id is blank" do
      admin = create(:user, role: "admin")
      note = Note.create!(title: "N", body: "B", notable_type: "User", notable_id: admin.id)

      patch iron_admin.resource_path("notes", note), params: {
        record: { title: "N", body: "B", notable_type: "Tag", notable_id: "" },
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(note.reload.notable_type).to eq("User")
    end

    it "renders no id options when the stored polymorphic type is outside the allowlist" do
      Tag.create!(name: "leaked-tag")
      note = Note.create!(title: "N", body: "B", notable_type: "Tag", notable_id: nil)

      get iron_admin.edit_resource_path("notes", note)

      expect(response).to have_http_status(:ok)
      expect(notable_id_select).to be_present
      expect(notable_id_option_values).to eq([])
    end
  end

  describe "many-to-many ids" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::TagResource)
    end

    it "rejects tag ids that include a tag outside the tenant" do
      visible = Tag.create!(name: "visible-tag")
      other = Tag.create!(name: "other-tag")
      post_record = Post.create!(title: "Scoped post")
      scope_tags_to_visible

      patch iron_admin.resource_path("posts", post_record), params: {
        record: { title: post_record.title, tag_ids: [visible.id, other.id] },
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("is not available")
      expect(post_record.reload.tags).to be_empty
    end

    it "saves tag ids that are all inside the tenant" do
      visible = Tag.create!(name: "visible-tag")
      Tag.create!(name: "other-tag")
      post_record = Post.create!(title: "Scoped post")
      scope_tags_to_visible

      patch iron_admin.resource_path("posts", post_record), params: {
        record: { title: post_record.title, tag_ids: [visible.id] },
      }

      expect(post_record.reload.tags).to contain_exactly(visible)
    end

    it "keeps many-to-many ids the tenant cannot assign" do
      visible = Tag.create!(name: "visible-tag")
      other = Tag.create!(name: "other-tag")
      post_record = Post.create!(title: "Scoped post")
      post_record.tags = [visible, other]
      scope_tags_to_visible

      patch iron_admin.resource_path("posts", post_record), params: {
        record: { title: post_record.title, tag_ids: [visible.id] },
      }

      expect(response).to have_http_status(:redirect)
      expect(post_record.reload.tags).to contain_exactly(visible, other)
    end
  end

  describe "nested belongs_to" do
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

    before { register_nest_parent_resource }

    it "rejects a nested foreign key outside the tenant" do
      visible = Tag.create!(name: "visible-tag")
      other = Tag.create!(name: "other-tag")
      parent = NestParent.create!(name: "Parent")
      child = parent.nest_children.create!(label: "Row", tag: visible)
      scope_tags_to_visible

      patch iron_admin.resource_path("nest_parents", parent), params: {
        record: { nest_children_attributes: { "0" => { id: child.id, tag_id: other.id } } },
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(child.reload.tag_id).to eq(visible.id)
    end

    it "saves a nested foreign key inside the tenant" do
      visible = Tag.create!(name: "visible-tag")
      Tag.create!(name: "other-tag")
      parent = NestParent.create!(name: "Parent")
      child = parent.nest_children.create!(label: "Row")
      scope_tags_to_visible

      patch iron_admin.resource_path("nest_parents", parent), params: {
        record: { nest_children_attributes: { "0" => { id: child.id, tag_id: visible.id } } },
      }

      expect(child.reload.tag_id).to eq(visible.id)
    end
  end

  def register_ref_license_resource
    resource = Class.new(IronAdmin::Resource) do
      def self.name = "RefLicenseResource"
      def self.resource_name = "ref_licenses"

      self.model_class_override = License
      belongs_to :user, display: :email
      form_fields :license_key, :license_type, :max_devices, :user
    end
    IronAdmin::ResourceRegistry.register(resource)
  end

  def register_nest_parent_resource
    resource = Class.new(IronAdmin::Resource) do
      def self.name = "NestParentResource"
      def self.resource_name = "nest_parents"

      self.model_class_override = NestParent
      has_many :nest_children, nested: true
    end
    IronAdmin::ResourceRegistry.register(resource)
  end

  def license_attributes(source, user_id)
    {
      license_key: source.license_key.presence || "REF-KEY",
      license_type: source.license_type.presence || "standard",
      max_devices: source.max_devices || 1,
      user_id: user_id,
    }
  end

  def scope_users_to_admins
    IronAdmin.configure do |c|
      c.tenant_scope { |scope| scope.model == User ? scope.where(role: "admin") : scope }
    end
  end

  def scope_tags_to_visible
    IronAdmin.configure do |c|
      c.tenant_scope { |scope| scope.model == Tag ? scope.where(name: "visible-tag") : scope }
    end
  end

  def scope_users_and_no_licenses
    IronAdmin.configure do |c|
      c.tenant_scope do |scope|
        if scope.model == License
          scope.none
        elsif scope.model == User
          scope.where(role: "admin")
        else
          scope
        end
      end
    end
  end

  def notable_id_select
    response.parsed_body.at_xpath("//select[@name='record[notable_id]']")
  end

  def notable_id_option_values
    options = notable_id_select&.css("option")
    return [] unless options

    options.filter_map { |option| option["value"].presence }
  end
end
