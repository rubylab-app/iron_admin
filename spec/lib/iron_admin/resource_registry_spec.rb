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

    it "falls back to the full class path for a namespaced resource" do
      namespaced = Class.new(IronAdmin::Resource) do
        def self.name
          "IronAdmin::Resources::Shop::NoteResource"
        end
      end
      allow(namespaced).to receive(:resource_name).and_raise(NameError, "missing")

      described_class.register(namespaced)

      expect(described_class.find("shop_notes")).to eq(namespaced)
    end
  end

  def named_registry_resource(class_name, resource_name)
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      define_singleton_method(:name) { class_name }
      define_singleton_method(:resource_name) { resource_name }
    end
  end

  context "when the same class name is registered again" do
    let(:original) { named_registry_resource("IronAdmin::Resources::WidgetResource", "widgets") }
    let(:reloaded) { named_registry_resource("IronAdmin::Resources::WidgetResource", "widgets") }

    before do
      described_class.register(original)
      described_class.register(reloaded)
    end

    it "replaces the stale class in the registry" do
      expect(described_class.find("widgets")).to equal(reloaded)
    end

    it "drops the stale class from the remembered list" do
      described_class.finalize!

      expect(described_class.find("widgets")).to equal(reloaded)
    end

    it "does not log a collision" do
      allow(Rails.logger).to receive(:error)

      described_class.finalize!

      expect(Rails.logger).not_to have_received(:error)
    end
  end

  context "when two different classes share a resource name" do
    let(:first_resource) { named_registry_resource("IronAdmin::Resources::FirstWidgetResource", "shared_widgets") }
    let(:second_resource) { named_registry_resource("IronAdmin::Resources::SecondWidgetResource", "shared_widgets") }

    it "keeps the first class" do
      described_class.register(first_resource)
      described_class.register(second_resource)
      described_class.finalize!

      expect(described_class.find("shared_widgets")).to equal(first_resource)
    end

    it "leaves the second class out of the registry" do
      described_class.register(first_resource)
      described_class.register(second_resource)
      described_class.finalize!

      expect(described_class.all).not_to include(second_resource)
    end

    it "logs the collision once, at finalize" do
      allow(Rails.logger).to receive(:error)
      described_class.register(first_resource)
      described_class.register(second_resource)

      expect(Rails.logger).not_to have_received(:error)

      described_class.finalize!

      expect(Rails.logger).to have_received(:error).with(
        /SecondWidgetResource.*shared_widgets.*FirstWidgetResource.*def self\.resource_name/m
      ).once
    end
  end

  context "when register cannot key an anonymous class" do
    it "does not raise from a later finalize!" do
      expect { described_class.register(Class.new(IronAdmin::Resource)) }.to raise_error(NoMethodError)

      expect { described_class.finalize! }.not_to raise_error
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
