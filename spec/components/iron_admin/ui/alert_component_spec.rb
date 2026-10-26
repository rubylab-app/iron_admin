require "rails_helper"
require_relative "../../../../app/components/iron_admin/ui/alert_component"

RSpec.describe IronAdmin::Ui::AlertComponent, type: :component do
  describe "#initialize" do
    it "stores message" do
      component = described_class.new(message: "Test message")
      expect(component.message).to eq("Test message")
    end

    it "defaults type to info" do
      component = described_class.new(message: "Test")
      expect(component.type).to eq(:info)
    end

    it "defaults dismissible to true" do
      component = described_class.new(message: "Test")
      expect(component.dismissible).to be true
    end

    it "accepts custom type" do
      component = described_class.new(message: "Test", type: :error)
      expect(component.type).to eq(:error)
    end
  end

  describe "#type_config" do
    it "returns success config" do
      component = described_class.new(message: "Test", type: :success)
      config = component.type_config
      expect(config[:bg]).to include("green")
      expect(config[:icon]).to eq("check-circle")
    end

    it "returns error config" do
      component = described_class.new(message: "Test", type: :error)
      config = component.type_config
      expect(config[:bg]).to include("red")
      expect(config[:icon]).to eq("x-circle")
    end

    it "returns warning config" do
      component = described_class.new(message: "Test", type: :warning)
      config = component.type_config
      expect(config[:bg]).to include("yellow")
    end

    it "returns info config" do
      component = described_class.new(message: "Test", type: :info)
      config = component.type_config
      expect(config[:bg]).to include("blue")
    end
  end

  describe "#render?" do
    it "returns true when message is present" do
      component = described_class.new(message: "Test")
      expect(component.render?).to be true
    end

    it "returns false when message is blank" do
      component = described_class.new(message: "")
      expect(component.render?).to be false
    end
  end

  describe "rendering" do
    subject(:alert) { rendered.at_css("[role]") }

    let(:rendered) { render_inline(component) }
    let(:component) { described_class.new(message: "Saved", type: type) }
    let(:type) { :success }

    %i[error warning].each do |assertive_type|
      context "with the #{assertive_type} type" do
        let(:type) { assertive_type }

        it "announces the message assertively" do
          expect(alert[:role]).to eq("alert")
        end
      end
    end

    %i[success info].each do |polite_type|
      context "with the #{polite_type} type" do
        let(:type) { polite_type }

        it "announces the message politely" do
          expect(alert[:role]).to eq("status")
        end
      end
    end

    context "when dismissible" do
      let(:dismiss_button) { rendered.at_css("button") }

      it "attaches the cp-alert Stimulus controller" do
        expect(alert["data-controller"]).to eq("cp-alert")
      end

      it "wires the dismiss button to the controller" do
        expect(dismiss_button["data-action"]).to eq("cp-alert#dismiss")
      end

      it "labels the dismiss button for screen readers" do
        expect(dismiss_button["aria-label"]).to eq("Dismiss")
      end
    end

    context "when not dismissible" do
      let(:component) { described_class.new(message: "Saved", dismissible: false) }

      it "renders no dismiss button" do
        expect(rendered.css("button")).to be_empty
      end

      it "attaches no Stimulus controller" do
        expect(alert["data-controller"]).to be_nil
      end
    end

    context "with a themed border radius" do
      before { IronAdmin.configuration.theme.border_radius = "rounded-none" }

      it "uses the theme's border radius" do
        expect(alert[:class].split).to include("rounded-none")
      end
    end
  end

  describe "dismiss controller" do
    subject(:entry_point) { IronAdmin::Engine.root.join("app/javascript/iron_admin/index.js").read }

    it "is registered under the identifier the template uses" do
      expect(entry_point).to include(%(application.register("cp-alert", CpAlertController)))
    end
  end
end
