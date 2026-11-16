# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tenant-scoped association selects", type: :request do
  describe "polymorphic belongs_to" do
    it "lists only tenant users in the id select" do
      admin = create(:user, name: "Admin In", role: "admin")
      create(:user, name: "Outsider Out", role: "member")
      note = Note.create!(title: "N", notable: admin)
      IronAdmin.configure do |c|
        c.tenant_scope { |scope| scope.model == User ? scope.where(role: "admin") : scope }
      end

      get iron_admin.edit_resource_path("notes", note)

      options = option_texts("//select[@name='record[notable_id]']")
      expect(response).to have_http_status(:ok)
      expect(options).to include("Admin In")
      expect(options).not_to include("Outsider Out")
    end
  end

  describe "HABTM checkboxes" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::TagResource)
    end

    it "lists only tenant tags" do
      Tag.create!(name: "visible-tag")
      Tag.create!(name: "other-tag")
      post = Post.create!(title: "Scoped post")
      IronAdmin.configure do |c|
        c.tenant_scope { |scope| scope.model == Tag ? scope.where(name: "visible-tag") : scope }
      end

      get iron_admin.edit_resource_path("posts", post)

      labels = checkbox_labels("record[tag_ids][]")
      expect(response).to have_http_status(:ok)
      expect(labels).to include("visible-tag")
      expect(labels).not_to include("other-tag")
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

    before do
      resource = Class.new(IronAdmin::Resource) do
        def self.name = "NestParentResource"
        def self.resource_name = "nest_parents"

        self.model_class_override = NestParent
        has_many :nest_children, nested: true
      end
      IronAdmin::ResourceRegistry.register(resource)
    end

    it "lists only tenant tags in the nested tag select" do
      Tag.create!(name: "visible-tag")
      Tag.create!(name: "other-tag")
      parent = NestParent.create!(name: "Parent")
      parent.nest_children.create!(label: "Row")
      IronAdmin.configure do |c|
        c.tenant_scope { |scope| scope.model == Tag ? scope.where(name: "visible-tag") : scope }
      end

      get iron_admin.edit_resource_path("nest_parents", parent)

      options = option_texts("//select[contains(@name, '[tag_id]')]")
      expect(response).to have_http_status(:ok)
      expect(options).to include("visible-tag")
      expect(options).not_to include("other-tag")
    end
  end

  def option_texts(xpath)
    response.parsed_body.xpath(xpath).css("option").map { |node| node.text.strip }
  end

  def checkbox_labels(input_name)
    response.parsed_body.xpath("//input[@name=#{input_name.inspect}]").map do |input|
      input.parent.text.gsub(/\s+/, " ").strip
    end
  end
end
