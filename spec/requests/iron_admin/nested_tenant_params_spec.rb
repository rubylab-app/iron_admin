# frozen_string_literal: true

require "rails_helper"

RSpec.describe "nested tenant attributes in submitted params", type: :request do
  before(:all) do
    ActiveRecord::Base.connection.create_table :param_nest_parents, force: true do |t|
      t.string :name
      t.timestamps
    end
    ActiveRecord::Base.connection.create_table :param_nest_children, force: true do |t|
      t.integer :param_nest_parent_id
      t.string :label
      t.timestamps
    end

    Object.const_set(:ParamNestChild, Class.new(ApplicationRecord) do
      self.table_name = "param_nest_children"
      belongs_to :param_nest_parent
    end)
    Object.const_set(:ParamNestParent, Class.new(ApplicationRecord) do
      self.table_name = "param_nest_parents"
      has_many :param_nest_children
      accepts_nested_attributes_for :param_nest_children
    end)
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :param_nest_children, if_exists: true
    ActiveRecord::Base.connection.drop_table :param_nest_parents, if_exists: true
    Object.send(:remove_const, :ParamNestChild) if defined?(ParamNestChild)
    Object.send(:remove_const, :ParamNestParent) if defined?(ParamNestParent)
  end

  let(:resource) do
    Class.new(IronAdmin::Resource) do
      def self.name = "ParamNestParentResource"
      def self.resource_name = "param_nest_parents"

      self.model_class_override = ParamNestParent
      has_many :param_nest_children, nested: true
    end
  end

  before do
    IronAdmin.configure do |config|
      config.tenant_scope do |scope|
        scope.model == ParamNestChild ? scope.where(label: "tenant") : scope
      end
    end
    IronAdmin::ResourceRegistry.register(resource)
  end

  it "passes tenant equalities into build_in for a new nested row" do
    bucket = capture_adapter_args(:build_in)

    post iron_admin.resources_path("param_nest_parents"), params: {
      record: { name: "Scoped", param_nest_children_attributes: { "0" => { label: "posted" } } },
    }

    expect(response).to have_http_status(:redirect)
    expect(nested_label(bucket.last, "0")).to eq("tenant")
  end

  it "passes tenant equalities into adapter.update for a new nested row" do
    parent = ParamNestParent.create!(name: "Old")
    bucket = capture_adapter_args(:update)

    patch iron_admin.resource_path("param_nest_parents", parent), params: {
      record: { name: "New", param_nest_children_attributes: { "0" => { label: "posted" } } },
    }

    expect(response).to have_http_status(:redirect)
    expect(nested_label(bucket.last, "0")).to eq("tenant")
  end

  def capture_adapter_args(method_name)
    adapter = resource.adapter
    allow(resource).to receive(:adapter).and_return(adapter)
    bucket = []
    allow(adapter).to receive(method_name).and_wrap_original do |original, *args|
      bucket << args.last
      original.call(*args)
    end
    bucket
  end

  def nested_label(attrs, index)
    return unless attrs.respond_to?(:to_h)

    attrs.to_h.dig("param_nest_children_attributes", index, "label")
  end
end
