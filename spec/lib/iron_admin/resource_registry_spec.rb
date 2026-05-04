require "rails_helper"
require_relative "../../support/test_resources"

RSpec.describe IronAdmin::ResourceRegistry do
  before { described_class.reset! }

  describe ".register" do
    it "registers a resource class" do
      described_class.register(TestUserResource)
      expect(described_class.all).to include(TestUserResource)
    end
  end

  describe ".find" do
    it "finds resource by model name" do
      described_class.register(TestUserResource)
      expect(described_class.find("users")).to eq(TestUserResource)
    end
  end

  describe ".grouped" do
    it "groups resources by menu group" do
      described_class.register(TestUserResource)
      described_class.register(TestLicenseResource)

      groups = described_class.grouped
      expect(groups["Licensing"]).to include(TestLicenseResource)
    end
  end

  describe ".sorted" do
    it "sorts by menu priority" do
      described_class.register(TestUserResource)
      described_class.register(TestLicenseResource)

      sorted = described_class.sorted
      # UserResource has priority 0, LicenseResource has priority 1
      # Lower priority should come first
      expect(sorted.first).to eq(TestUserResource)
    end
  end

  describe ".register robustness" do
    let(:flaky_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "FlakyResource"
        end

        def self.resource_name
          "flakies"
        end
      end
    end

    it "still adds the resource to the registry when soft-delete registration raises" do
      allow(flaky_resource).to receive(:register_soft_delete_features).and_raise(NoMethodError, "boom")

      described_class.register(flaky_resource)

      expect(described_class.all).to include(flaky_resource)
    end

    it "returns the resource class even on soft-delete failure" do
      allow(flaky_resource).to receive(:register_soft_delete_features).and_raise(NoMethodError, "boom")

      expect(described_class.register(flaky_resource)).to eq(flaky_resource)
    end

    it "falls back to a class-name-derived key when resource_name (adapter-driven) raises" do
      adapter_dependent_resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "IronAdmin::Resources::AdapterDependentResource"
        end
      end
      allow(adapter_dependent_resource).to receive(:resource_name)
        .and_raise(NameError, "uninitialized constant AdapterDependent")

      described_class.register(adapter_dependent_resource)

      expect(described_class.find("adapter_dependents")).to eq(adapter_dependent_resource)
    end
  end

  describe ".finalize!" do
    let(:resource_a) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "ResourceA"
        end

        def self.resource_name
          "resource_a"
        end
      end
    end

    let(:resource_b) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "ResourceB"
        end

        def self.resource_name
          "resource_b"
        end
      end
    end

    before do
      described_class.register(resource_a)
      described_class.register(resource_b)
    end

    it "calls register_soft_delete_features on every registered resource" do
      allow(resource_a).to receive(:register_soft_delete_features)
      allow(resource_b).to receive(:register_soft_delete_features)

      described_class.finalize!

      expect(resource_a).to have_received(:register_soft_delete_features)
      expect(resource_b).to have_received(:register_soft_delete_features)
    end

    it "logs a warning and continues when a resource raises" do
      allow(resource_a).to receive(:register_soft_delete_features).and_raise(NoMethodError, "boom")
      allow(resource_b).to receive(:register_soft_delete_features)
      allow(Rails.logger).to receive(:warn)

      expect { described_class.finalize! }.not_to raise_error

      expect(Rails.logger).to have_received(:warn)
        .with(/Could not finalize ResourceA.*NoMethodError.*boom/)
      expect(resource_b).to have_received(:register_soft_delete_features)
    end

    it "invalidates each resource's memoized @adapter" do
      # Force memoization with a stale adapter, then verify finalize!
      # clears it so the next access re-resolves.
      resource_a.instance_variable_set(:@adapter, :stale_adapter_marker)

      described_class.finalize!

      expect(resource_a.instance_variable_get(:@adapter)).not_to eq(:stale_adapter_marker)
    end
  end
end
