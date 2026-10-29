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

  describe "progress bar" do
    subject(:bar) { render_inline(described_class.new(title: "Signups", value: 40, max: 200)).at_css("[role=progressbar]") }

    it "names the bar after the title" do
      expect(bar["aria-label"]).to eq("Signups")
    end

    # The percentage stays within 0..100 even when the value passes the target.
    it "exposes the completion percentage to assistive technology" do
      expect(bar.attributes.slice("aria-valuemin", "aria-valuemax", "aria-valuenow").transform_values(&:value))
        .to eq("aria-valuemin" => "0", "aria-valuemax" => "100", "aria-valuenow" => "20.0")
    end

    it "reads out the value and the target" do
      expect(bar["aria-valuetext"]).to eq("40 / 200")
    end

    it "draws the track in the theme's progress_track and control_radius" do
      expect(bar[:class].split).to include(*IronAdmin.current_theme.progress_track.split, IronAdmin.current_theme.control_radius)
    end

    it "fills the bar in the bar color" do
      expect(bar.at_css("div")[:style]).to include("background-color: #{IronAdmin.current_theme.chart_border_color}")
    end
  end

  describe "theme classes" do
    subject(:card) { render_inline(described_class.new(title: "Signups", value: 40, max: 200)).at_css("div") }

    let(:title) { card.at_css("h2") }
    let(:figure) { card.css("span").find { |span| span.text.strip == "40" } }

    context "with the default theme" do
      # HAML's dot syntax reads ".py-3.5" as the classes "py-3" and "5".
      it "keeps fractional sizes such as py-3.5 whole" do
        expect(card.css("[class]").flat_map { |node| node[:class].split }).not_to include(match(/\A\d+\z/))
      end

      it "frames the card with the theme's surface, border, radius and shadow" do
        expect(card[:class].split).to include(*%w[bg-white border border-zinc-200 rounded-lg shadow-xs])
      end

      it "puts the title on top in the theme's metric_label" do
        expect(title[:class].split).to include(*IronAdmin.current_theme.metric_label.split)
      end

      it "shows the value in the theme's metric_value" do
        expect(figure[:class].split).to include(*IronAdmin.current_theme.metric_value.split)
      end

      # On a phone "$123,456.78 / $250,000.00" wrapped between the slash and the target.
      it "keeps the slash on the target's line" do
        expect(card.css("span").find { |span| span.text.strip == "/ 200" }[:class].split).to include("whitespace-nowrap")
      end
    end

    context "with a registered theme active for the request" do
      before do
        IronAdmin::RequestContext.theme = IronAdmin.configuration.register_theme(:harbor) do |t|
          t.border_width = "border-2"
          t.progress_track = "bg-slate-800"
          t.control_radius = "rounded-none"
          t.metric_value = "text-4xl font-black text-white"
          t.chart_border_color = "rgb(56, 189, 248)"
        end
      end

      it "frames the card with that theme's border width" do
        expect(card[:class].split).to include("border-2")
      end

      it "draws the track in that theme's progress_track and control_radius" do
        expect(card.at_css("[role=progressbar]")[:class].split).to include("bg-slate-800", "rounded-none")
      end

      it "fills the bar in that theme's chart_border_color" do
        expect(card.at_css("[role=progressbar] div")[:style]).to include("background-color: rgb(56, 189, 248)")
      end

      # Tailwind does not guarantee which of two font sizes wins, so only the theme sets one.
      it "leaves the value's size and color to that theme's metric_value" do
        expect(figure[:class].split.grep(/text-/)).to eq(%w[text-4xl text-white])
      end
    end
  end

  # The dashboard page title is the h1, so a widget title is an h2.
  describe "widget title" do
    subject(:headings) do
      render_inline(described_class.new(title: "Signups", value: 50, max: 100))
        .css("h1, h2, h3, h4, h5, h6")
    end

    it "is an h2, one level below the page title" do
      expect(headings.map { |heading| [heading.name, heading.text.squish] }).to eq([%w[h2 Signups]])
    end
  end
end
