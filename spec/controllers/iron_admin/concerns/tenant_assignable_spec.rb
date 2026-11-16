# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Concerns::TenantAssignable do
  let(:adapter) { instance_double(IronAdmin::Adapters::ActiveRecord) }

  let(:resource_class) do
    reflection = Struct.new(:klass).new(License)
    nested = Struct.new(:name, :reflection, :kind).new(:licenses, reflection, :has_many)
    Class.new do
      define_singleton_method(:nested_associations) { [nested] }
    end
  end

  let(:harness) do
    concern = described_class
    resource = resource_class
    record_adapter = adapter
    Class.new do
      include concern

      def initialize(resource, record_adapter)
        @resource_class = resource
        @record_adapter = record_adapter
      end

      def adapter
        @record_adapter
      end

      def stamp(attrs)
        with_nested_tenant_attributes(attrs)
      end
    end.new(resource, record_adapter)
  end

  before do
    allow(adapter).to receive(:scope_attributes).and_return("label" => "tenant")
  end

  it "returns the submitted attributes unchanged when no tenant scope is configured" do
    attrs = ActionController::Parameters.new(
      "licenses_attributes" => { "0" => { "label" => "posted" } }
    ).permit!

    expect(harness.stamp(attrs)).to equal(attrs)
    expect(adapter).not_to have_received(:scope_attributes)
  end

  it "merges tenant equalities into new nested rows and drops the tenant column from rows with an id" do
    configure_tenant
    attrs = {
      "licenses_attributes" => {
        "0" => { "label" => "posted", "name" => "n" },
        "1" => { "id" => "5", "label" => "posted" },
        "2" => { "id" => "", "label" => "posted" },
      },
    }

    expect(harness.stamp(attrs)).to eq(
      "licenses_attributes" => {
        "0" => { "label" => "tenant", "name" => "n" },
        "1" => { "id" => "5" },
        "2" => { "id" => "", "label" => "tenant" },
      }
    )
    expect(attrs["licenses_attributes"]["0"]["label"]).to eq("posted")
  end

  it "merges tenant equalities into an array of new nested rows" do
    configure_tenant
    attrs = {
      "licenses_attributes" => [
        { "label" => "posted" },
        { "id" => 4, "label" => "posted" },
      ],
    }

    expect(harness.stamp(attrs)).to eq(
      "licenses_attributes" => [
        { "label" => "tenant" },
        { "id" => 4 },
      ]
    )
  end

  it "returns a string-keyed hash when permitted parameters include new nested rows" do
    configure_tenant
    attrs = ActionController::Parameters.new(
      "name" => "Parent",
      "licenses_attributes" => { "0" => { "label" => "posted" } }
    ).permit!

    stamped = harness.stamp(attrs)

    expect(stamped).to be_a(Hash)
    expect(stamped.keys).to all(be_a(String))
    expect(stamped["licenses_attributes"]["0"]["label"]).to eq("tenant")
    expect(stamped["name"]).to eq("Parent")
  end

  def configure_tenant
    IronAdmin.configure do |config|
      config.tenant_scope { |scope| scope }
    end
  end
end
