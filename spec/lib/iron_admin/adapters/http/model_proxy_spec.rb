# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/http"

RSpec.describe IronAdmin::Adapters::Http::ModelProxy do
  subject(:proxy) { described_class.new(resource_class) }

  let(:resource_class) do
    Class.new(IronAdmin::Resource) do
      def self.name
        "IronAdmin::Resources::ExternalCustomerResource"
      end
    end
  end

  describe "#model_name" do
    it "returns an ActiveModel::Name" do
      expect(proxy.model_name).to be_a(ActiveModel::Name)
    end

    it "exposes a plural derived from the resource class name" do
      expect(proxy.model_name.plural).to eq("external_customers")
    end

    it "exposes a human-readable name" do
      expect(proxy.model_name.human).to eq("External customer")
    end
  end

  describe "#name" do
    it "strips the IronAdmin::Resources:: prefix and Resource suffix" do
      expect(proxy.name).to eq("ExternalCustomer")
    end

    it "is aliased to to_s" do
      expect(proxy.to_s).to eq(proxy.name)
    end
  end

  describe "#column_names" do
    it "returns an empty array (HTTP resources have no static schema)" do
      expect(proxy.column_names).to eq([])
    end
  end

  describe "integration with Resource.model" do
    let(:http_resource) do
      Class.new(IronAdmin::Resource) do
        self.adapter_class = :http

        def self.name
          "IronAdmin::Resources::NonExistentRemoteThingResource"
        end
      end
    end

    it "returns a ModelProxy when the resource uses the HTTP adapter and no Ruby model exists" do
      expect(http_resource.model).to be_a(described_class)
    end

    it "does not require a Ruby class with the inferred name to exist" do
      # Sanity: there is no `NonExistentRemoteThing` constant in the test environment.
      expect(defined?(NonExistentRemoteThing)).to be_nil
      expect { http_resource.model }.not_to raise_error
    end
  end
end
