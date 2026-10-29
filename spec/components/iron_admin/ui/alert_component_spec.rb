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
    {
      success: "check-circle",
      error: "x-circle",
      warning: "exclamation-triangle",
      info: "information-circle",
    }.each do |type, icon|
      context "with the #{type} type" do
        subject(:config) { described_class.new(message: "Test", type: type).type_config }

        it "uses the #{icon} icon" do
          expect(config[:icon]).to eq(icon)
        end
      end
    end

    context "with an unknown type" do
      subject(:config) { described_class.new(message: "Test", type: :notice).type_config }

      it "uses the info icon" do
        expect(config[:icon]).to eq("information-circle")
      end
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

    context "with an explicit role" do
      let(:component) { described_class.new(message: "Saved", type: :success, role: "alert") }

      it "uses it instead of the role of the type" do
        expect(alert[:role]).to eq("alert")
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

    context "with a themed alert shadow" do
      before { IronAdmin.configuration.theme.alert_shadow = "shadow-[4px_4px_0_#000]" }

      it "uses the theme's alert_shadow" do
        expect(alert[:class].split).to include("shadow-[4px_4px_0_#000]")
      end
    end

    context "with a themed border radius" do
      before { IronAdmin.configuration.theme.border_radius = "rounded-none" }

      it "uses the theme's border radius" do
        expect(alert[:class].split).to include("rounded-none")
      end
    end

    {
      success: %w[bg-emerald-50 border-emerald-200 text-emerald-800],
      error: %w[bg-red-50 border-red-200 text-red-800],
      warning: %w[bg-amber-50 border-amber-200 text-amber-800],
      info: %w[bg-blue-50 border-blue-200 text-blue-800],
    }.each do |palette_type, classes|
      context "with the #{palette_type} type and the default theme" do
        let(:type) { palette_type }

        it "tints the alert with the theme's alert_palette" do
          expect(alert[:class].split).to include(*classes)
        end
      end
    end

    it "draws the border with the theme's border_width" do
      expect(alert[:class].split).to include("border")
    end

    context "with an unknown type" do
      let(:type) { :notice }

      it "uses the info colors" do
        expect(alert[:class].split).to include("bg-blue-50")
      end
    end

    context "with a registered theme active" do
      before do
        IronAdmin::RequestContext.theme = IronAdmin.configuration.register_theme(:brutal) do |t|
          t.alert_palette = { success: "bg-lime-300 border-black text-black", info: "bg-white border-black text-black" }
          t.border_width = "border-2"
        end
      end

      it "uses that theme's alert_palette" do
        expect(alert[:class].split).to include("bg-lime-300", "border-black", "text-black")
      end

      it "drops the default theme's palette" do
        expect(alert[:class].split).not_to include("bg-emerald-50")
      end

      it "draws the border with that theme's border_width" do
        expect(alert[:class].split).to include("border-2")
      end

      context "when its palette has no entry for the type" do
        let(:type) { :warning }

        it "uses its info entry" do
          expect(alert[:class].split).to include("bg-white", "border-black")
        end
      end
    end

    context "when dismissible, with the default theme" do
      subject(:dismiss_button) { rendered.at_css("button")[:class].split }

      it "rounds the dismiss button with the theme's control_radius" do
        expect(dismiss_button).to include("rounded-md")
      end

      it "outlines the focused dismiss button with the theme's focus_ring" do
        expect(dismiss_button).to include("focus-visible:outline-indigo-500")
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
