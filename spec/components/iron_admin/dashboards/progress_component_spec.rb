require "rails_helper"
require_relative "../../../../app/components/iron_admin/dashboards/progress_component"

RSpec.describe IronAdmin::Dashboards::ProgressComponent, type: :component do
  describe "#initialize" do
    subject(:component) { described_class.new(title: "Signups", value: 40, max: 200) }

    it "requires a title" do
      expect(component.title).to eq("Signups")
    end

    it "coerces value to a float" do
      expect(component.value).to eq(40.0)
    end

    it "coerces max to a float" do
      expect(component.max).to eq(200.0)
    end

    it "defaults max to 100" do
      expect(described_class.new(title: "Signups", value: 40).max).to eq(100.0)
    end

    it "defaults format to number" do
      expect(described_class.new(title: "Signups", value: 40).format).to eq(:number)
    end
  end

  describe "#percentage" do
    it "computes the completion ratio" do
      component = described_class.new(title: "Goal", value: 25, max: 100)
      expect(component.percentage).to eq(25.0)
    end

    it "clamps values above the max to 100" do
      component = described_class.new(title: "Goal", value: 150, max: 100)
      expect(component.percentage).to eq(100.0)
    end

    context "when max is zero" do
      it "returns zero instead of dividing by zero" do
        component = described_class.new(title: "Goal", value: 5, max: 0)
        expect(component.percentage).to eq(0.0)
      end
    end
  end

  describe "#bar_color" do
    context "without a custom color" do
      it "falls back to the theme border color" do
        component = described_class.new(title: "Goal", value: 5)
        expect(component.bar_color).to eq(IronAdmin.configuration.theme.chart_border_color)
      end
    end

    context "with a custom color" do
      it "uses the provided color" do
        component = described_class.new(title: "Goal", value: 5, color: "#10b981")
        expect(component.bar_color).to eq("#10b981")
      end
    end
  end

  describe "rendering" do
    it "renders the title" do
      result = render_inline(described_class.new(title: "Signups", value: 50, max: 100))
      expect(result.text).to include("Signups")
    end

    it "renders the completion percentage" do
      result = render_inline(described_class.new(title: "Signups", value: 25, max: 100))
      expect(result.text).to include("25.0%")
    end

    it "formats currency values" do
      result = render_inline(described_class.new(title: "Revenue", value: 1500, max: 5000, format: :currency))
      expect(result.text).to include("$1,500.00")
    end

    it "fills the bar to the computed width" do
      result = render_inline(described_class.new(title: "Goal", value: 25, max: 100))
      expect(result.to_html).to include("width: 25.0%")
    end
  end
end
