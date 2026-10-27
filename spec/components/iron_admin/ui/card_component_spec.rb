require "rails_helper"
require_relative "../../../../app/components/iron_admin/ui/card_component"

RSpec.describe IronAdmin::Ui::CardComponent, type: :component do
  describe "#initialize" do
    it "defaults padding to true" do
      component = described_class.new
      expect(component.padding).to be true
    end

    it "defaults shadow to true" do
      component = described_class.new
      expect(component.shadow).to be true
    end

    it "accepts custom padding" do
      component = described_class.new(padding: false)
      expect(component.padding).to be false
    end

    it "accepts custom shadow" do
      component = described_class.new(shadow: false)
      expect(component.shadow).to be false
    end
  end

  describe "#card_classes" do
    it "includes overflow-hidden" do
      component = described_class.new
      expect(component.card_classes).to include("overflow-hidden")
    end

    it "includes border class" do
      component = described_class.new
      expect(component.card_classes).to include("border")
    end

    it "includes shadow when enabled" do
      component = described_class.new(shadow: true)
      expect(component.card_classes).to include("shadow")
    end

    it "excludes shadow when disabled" do
      component = described_class.new(shadow: false)
      classes = component.card_classes
      expect(classes).not_to match(/\bshadow\b/)
    end

    context "with the default theme" do
      subject(:classes) { described_class.new.card_classes.split }

      it "draws the card as a theme surface" do
        expect(classes).to include("bg-white", "border", "border-zinc-200", "rounded-lg", "shadow-xs")
      end
    end

    context "with a registered theme active" do
      subject(:classes) { described_class.new.card_classes.split }

      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:brutal) do |t|
          t.border_width = "border-2"
          t.card_border = "border-black"
        end
      end

      it "draws the border with that theme's border_width and card_border" do
        expect(classes).to include("border-2", "border-black")
      end

      it "drops the default theme's border width" do
        expect(classes).not_to include("border")
      end
    end
  end

  describe "#content_classes" do
    it "returns p-6 when padding is true" do
      component = described_class.new(padding: true)
      expect(component.content_classes).to eq("p-6")
    end

    it "returns empty string when padding is false" do
      component = described_class.new(padding: false)
      expect(component.content_classes).to eq("")
    end
  end

  describe "slots" do
    it "has header slot" do
      expect(described_class.registered_slots).to have_key(:header)
    end

    it "has footer slot" do
      expect(described_class.registered_slots).to have_key(:footer)
    end
  end
end
