# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::PluginRegistry do
  def build_plugin(name: "test_plugin", &body)
    Class.new(IronAdmin::Plugin) do
      plugin_name name
      instance_eval(&body) if body
    end
  end

  describe ".register" do
    context "with a valid plugin" do
      it "stores the plugin" do
        plugin = build_plugin(name: "reports")
        described_class.register(plugin)
        expect(described_class.find("reports")).to eq(plugin)
      end

      it "activates the plugin immediately" do
        activated = false
        plugin = build_plugin { setup { |_admin| activated = true } }

        described_class.register(plugin)
        expect(activated).to be true
      end
    end

    context "when registering the same plugin name twice" do
      it "does not create a duplicate entry" do
        described_class.register(build_plugin(name: "dup"))
        described_class.register(build_plugin(name: "dup"))
        expect(described_class.all.size).to eq(1)
      end
    end

    context "with an object that is not a Plugin subclass" do
      it "raises a PluginError" do
        expect { described_class.register(Class.new) }
          .to raise_error(IronAdmin::PluginError, /not an IronAdmin::Plugin subclass/)
      end
    end

    context "with an incompatible plugin" do
      it "raises IncompatiblePluginError" do
        plugin = build_plugin { requires_iron_admin ">= 99.0" }
        expect { described_class.register(plugin) }
          .to raise_error(IronAdmin::IncompatiblePluginError)
      end
    end
  end

  describe ".activate_all!" do
    it "re-runs activation for every registered plugin" do
      call_count = 0
      plugin = build_plugin { setup { |_admin| call_count += 1 } }
      described_class.register(plugin) # first activation

      described_class.activate_all!
      expect(call_count).to eq(2)
    end

    context "when a plugin registers a field type (re-activated on to_prepare reloads)" do
      it "does not raise on the second activation" do
        plugin = build_plugin(name: "swatch") do
          setup { |admin| admin.field_type(:plugin_swatch) { display { |v| v } } }
        end
        described_class.register(plugin) # first activation registers the type

        expect { described_class.activate_all! }.not_to raise_error
        expect(IronAdmin::FieldTypeRegistry.registered?(:plugin_swatch)).to be true
      end
    end
  end

  describe ".reset!" do
    it "clears all registered plugins" do
      described_class.register(build_plugin)
      described_class.reset!
      expect(described_class.all).to be_empty
    end
  end
end
