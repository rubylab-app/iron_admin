require "rails_helper"
require_relative "../../../../app/components/iron_admin/ui/tooltip_component"

RSpec.describe IronAdmin::Ui::TooltipComponent, type: :component do
  describe "#initialize" do
    it "stores text" do
      component = described_class.new(text: "Helpful info")
      expect(component.text).to eq("Helpful info")
    end

    it "defaults position to top" do
      component = described_class.new(text: "Info")
      expect(component.position).to eq(:top)
    end

    it "accepts custom position" do
      component = described_class.new(text: "Info", position: :bottom)
      expect(component.position).to eq(:bottom)
    end

    it "converts string position to symbol" do
      component = described_class.new(text: "Info", position: "left")
      expect(component.position).to eq(:left)
    end
  end

  describe "#position_classes" do
    it "returns top position classes" do
      component = described_class.new(text: "Info", position: :top)
      expect(component.position_classes).to include("bottom-full")
      expect(component.position_classes).to include("mb-2")
    end

    it "returns bottom position classes" do
      component = described_class.new(text: "Info", position: :bottom)
      expect(component.position_classes).to include("top-full")
      expect(component.position_classes).to include("mt-2")
    end

    it "returns left position classes" do
      component = described_class.new(text: "Info", position: :left)
      expect(component.position_classes).to include("right-full")
      expect(component.position_classes).to include("mr-2")
    end

    it "returns right position classes" do
      component = described_class.new(text: "Info", position: :right)
      expect(component.position_classes).to include("left-full")
      expect(component.position_classes).to include("ml-2")
    end

    it "falls back to top for unknown position" do
      component = described_class.new(text: "Info", position: :unknown)
      expect(component.position_classes).to include("bottom-full")
    end
  end

  describe "#tooltip_classes" do
    it "includes absolute positioning" do
      component = described_class.new(text: "Info")
      expect(component.tooltip_classes).to include("absolute")
    end

    it "includes position classes" do
      component = described_class.new(text: "Info", position: :bottom)
      expect(component.tooltip_classes).to include("top-full")
    end

    it "includes base styling" do
      component = described_class.new(text: "Info")
      expect(component.tooltip_classes).to include("text-xs")
    end

    it "colors the tooltip with the theme's tooltip classes" do
      component = described_class.new(text: "Info")
      expect(component.tooltip_classes.split).to include("bg-zinc-900", "text-white")
    end

    it "rounds the tooltip with the theme's control_radius" do
      component = described_class.new(text: "Info")
      expect(component.tooltip_classes.split).to include("rounded-md")
    end

    it "shows the tooltip while its trigger has keyboard focus" do
      component = described_class.new(text: "Info")
      expect(component.tooltip_classes.split).to include("group-focus-within:opacity-100", "group-focus-within:visible")
    end

    context "with a registered theme active" do
      subject(:classes) { described_class.new(text: "Info").tooltip_classes.split }

      before do
        IronAdmin::RequestContext.theme = IronAdmin.configuration.register_theme(:midnight) do |t|
          t.tooltip = "bg-white text-zinc-900"
        end
      end

      it "uses that theme's tooltip classes" do
        expect(classes).to include("bg-white", "text-zinc-900")
      end

      it "drops the default theme's tooltip classes" do
        expect(classes).not_to include("bg-zinc-900")
      end
    end

    it "includes visibility classes" do
      component = described_class.new(text: "Info")
      expect(component.tooltip_classes).to include("opacity-0")
      expect(component.tooltip_classes).to include("group-hover:opacity-100")
    end

    it "includes z-index" do
      component = described_class.new(text: "Info")
      expect(component.tooltip_classes).to include("z-50")
    end
  end
end
