# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Plugin do
  # Builds an anonymous plugin subclass with an explicit name so it does not
  # depend on constant assignment.
  def build_plugin(name: "test_plugin", &body)
    Class.new(described_class) do
      plugin_name name
      instance_eval(&body) if body
    end
  end

  describe ".plugin_name" do
    it "returns the declared name" do
      plugin = build_plugin(name: "reports")
      expect(plugin.plugin_name).to eq("reports")
    end
  end

  describe ".plugin_version" do
    it "returns the declared version" do
      plugin = build_plugin { plugin_version "1.2.0" }
      expect(plugin.plugin_version).to eq("1.2.0")
    end
  end

  describe ".compatible_with?" do
    context "when no requirement is declared" do
      it "is always compatible" do
        plugin = build_plugin
        expect(plugin).to be_compatible_with("0.6.0")
      end
    end

    context "when the running version satisfies the requirement" do
      it "returns true" do
        plugin = build_plugin { requires_iron_admin ">= 0.6", "< 2.0" }
        expect(plugin.compatible_with?("0.6.0")).to be true
      end
    end

    context "when the running version does not satisfy the requirement" do
      it "returns false" do
        plugin = build_plugin { requires_iron_admin ">= 2.0" }
        expect(plugin.compatible_with?("0.6.0")).to be false
      end
    end
  end

  describe ".activate!" do
    context "when the plugin is compatible" do
      it "runs the setup block with a Registration facade" do
        received = nil
        plugin = build_plugin do
          setup { |admin| received = admin }
        end

        plugin.activate!
        expect(received).to be_a(IronAdmin::Plugin::Registration)
      end
    end

    context "when the plugin is incompatible" do
      it "raises IncompatiblePluginError" do
        plugin = build_plugin { requires_iron_admin ">= 99.0" }
        expect { plugin.activate! }
          .to raise_error(IronAdmin::IncompatiblePluginError, /requires IronAdmin/)
      end
    end
  end
end

RSpec.describe IronAdmin::Plugin::Registration do
  subject(:registration) { described_class.new(plugin) }

  let(:plugin) { Class.new(IronAdmin::Plugin) { plugin_name "test" } }

  describe "#menu_item" do
    it "registers a MenuItem in the MenuRegistry" do
      registration.menu_item(label: "Reports", path: "/admin/reports")
      expect(IronAdmin::MenuRegistry.all.map(&:label)).to eq(["Reports"])
    end
  end

  describe "#component" do
    let(:custom_component) { Class.new }

    context "with a known component slot" do
      it "overrides the component on the global configuration" do
        registration.component(:navbar, custom_component)
        expect(IronAdmin.configuration.components.navbar).to eq(custom_component)
      end
    end

    context "with an unknown component slot" do
      it "raises an ArgumentError" do
        expect { registration.component(:nope, custom_component) }
          .to raise_error(ArgumentError, /Unknown component slot/)
      end
    end
  end

  describe "#field_type" do
    it "registers a field type in the FieldTypeRegistry" do
      registration.field_type(:color) do
        display { |record, field| record.public_send(field.name) }
      end

      expect(IronAdmin::FieldTypeRegistry.registered?(:color)).to be true
    end
  end
end
