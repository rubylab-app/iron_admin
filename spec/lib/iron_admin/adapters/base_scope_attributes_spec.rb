# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Adapters::Base do
  let(:active_record_adapter) do
    resource = Class.new(IronAdmin::Resource) do
      def self.name = "ScopeAttributeLicenseResource"
      def self.resource_name = "scope_attribute_licenses"

      self.model_class_override = License
    end
    IronAdmin::ResourceRegistry.register(resource)
    resource.adapter
  end

  describe "#scope_attributes" do
    it "returns an empty hash" do
      expect(described_class.allocate.scope_attributes(License.all)).to eq({})
    end

    it "keeps scalar equalities that are attributes of the scope model" do
      attributes = active_record_adapter.scope_attributes(License.where(user_id: 7, status: :active))

      expect(attributes).to include("user_id" => 7)
    end

    it "omits an IN list" do
      attributes = active_record_adapter.scope_attributes(License.where(user_id: [1, 2]))

      expect(attributes).not_to have_key("user_id")
    end

    it "omits a condition that is not an attribute of the scope model" do
      scope = double("scope", where_values_hash: { "user_id" => 3, "active" => true }, klass: License)

      expect(active_record_adapter.scope_attributes(scope)).to eq("user_id" => 3)
    end
  end

  describe "#build_in" do
    it "keeps the tenant when submitted attributes name another tenant" do
      tenant = create(:user)
      other = create(:user)
      record = active_record_adapter.build_in(
        License.where(user_id: tenant.id),
        { "user_id" => other.id, "license_key" => "K" }
      )

      expect(record.user_id).to eq(tenant.id)
      expect(record.license_key).to eq("K")
    end
  end
end
