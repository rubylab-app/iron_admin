require "rails_helper"
require_relative "../../../../app/components/iron_admin/dashboards/chart_component"

RSpec.describe IronAdmin::Dashboards::ChartComponent, type: :component do
  describe "#initialize" do
    it "requires title" do
      component = described_class.new(title: "Revenue")
      expect(component.title).to eq("Revenue")
    end

    it "defaults type to line" do
      component = described_class.new(title: "Revenue")
      expect(component.type).to eq(:line)
    end

    it "defaults height to 300" do
      component = described_class.new(title: "Revenue")
      expect(component.height).to eq(300)
    end

    it "accepts data and labels" do
      component = described_class.new(
        title: "Revenue",
        data: [100, 200, 300],
        labels: %w[Jan Feb Mar]
      )
      expect(component.data).to eq([100, 200, 300])
      expect(component.labels).to eq(%w[Jan Feb Mar])
    end

    it "accepts custom type" do
      component = described_class.new(title: "Revenue", type: :bar)
      expect(component.type).to eq(:bar)
    end
  end

  describe "#chart_id" do
    it "returns unique id" do
      component = described_class.new(title: "Revenue")
      expect(component.chart_id).to start_with("chart-")
    end
  end

  describe "#chart_config" do
    it "returns valid JSON" do
      component = described_class.new(
        title: "Revenue",
        data: [100, 200],
        labels: %w[Jan Feb]
      )
      config = JSON.parse(component.chart_config)
      expect(config["type"]).to eq("line")
      expect(config["data"]["labels"]).to eq(%w[Jan Feb])
    end

    it "includes datasets" do
      component = described_class.new(
        title: "Revenue",
        data: [100, 200],
        labels: %w[Jan Feb]
      )
      config = JSON.parse(component.chart_config)
      expect(config["data"]["datasets"]).to be_present
      expect(config["data"]["datasets"].first["data"]).to eq([100, 200])
    end

    context "with per-chart colors on bar chart" do
      it "uses per-chart colors as backgroundColor" do
        custom = ["#10b981", "#3b82f6"]
        component = described_class.new(title: "Status", type: :bar, data: [5, 10], labels: %w[A B], colors: custom)
        config = JSON.parse(component.chart_config)
        expect(config["data"]["datasets"].first["backgroundColor"]).to eq(custom)
        expect(config["data"]["datasets"].first["borderColor"]).to eq("#10b981")
      end
    end

    context "with per-chart colors on line chart" do
      it "uses first color as borderColor and transparent fill" do
        custom = ["#10b981", "#3b82f6"]
        component = described_class.new(title: "Trend", type: :line, data: [5, 10], labels: %w[A B], colors: custom)
        config = JSON.parse(component.chart_config)
        expect(config["data"]["datasets"].first["borderColor"]).to eq("#10b981")
        expect(config["data"]["datasets"].first["backgroundColor"]).to eq("#10b9811A")
      end
    end

    context "with an area chart" do
      subject(:config) { JSON.parse(described_class.new(title: "Volume", type: :area, data: [1], labels: ["A"]).chart_config) }

      it "renders as a line chart in Chart.js" do
        expect(config["type"]).to eq("line")
      end

      it "fills the dataset" do
        expect(config["data"]["datasets"].first["fill"]).to be(true)
      end
    end

    context "with a line chart" do
      subject(:config) { JSON.parse(described_class.new(title: "Trend", type: :line, data: [1], labels: ["A"]).chart_config) }

      it "fills the dataset (backward compatible with pre-:area behavior)" do
        expect(config["data"]["datasets"].first["fill"]).to be(true)
      end
    end

    context "with a horizontal bar chart" do
      subject(:config) { JSON.parse(described_class.new(title: "Ranking", type: :horizontal_bar, data: [1], labels: ["A"]).chart_config) }

      it "renders as a bar chart in Chart.js" do
        expect(config["type"]).to eq("bar")
      end

      it "sets the primary axis to y" do
        expect(config["options"]["indexAxis"]).to eq("y")
      end
    end

    context "with a radar chart" do
      subject(:config) { JSON.parse(described_class.new(title: "Skills", type: :radar, data: [1], labels: ["A"]).chart_config) }

      it "keeps the radar type" do
        expect(config["type"]).to eq("radar")
      end

      it "fills the dataset" do
        expect(config["data"]["datasets"].first["fill"]).to be(true)
      end
    end

    context "with a polar area chart" do
      subject(:config) { JSON.parse(described_class.new(title: "Split", type: :polar_area, data: [1, 2], labels: %w[A B], colors: ["#111", "#222"]).chart_config) }

      it "maps to the polarArea Chart.js type" do
        expect(config["type"]).to eq("polarArea")
      end

      it "displays a legend" do
        expect(config["options"]["plugins"]["legend"]["display"]).to be(true)
      end

      it "uses the color palette as backgroundColor" do
        expect(config["data"]["datasets"].first["backgroundColor"]).to eq(["#111", "#222"])
      end
    end

    context "with theme border color" do
      before do
        IronAdmin.configuration.theme.chart_border_color = "rgb(34, 197, 94)"
      end

      it "uses theme border color for line chart" do
        component = described_class.new(title: "Trend", type: :line, data: [5], labels: ["A"])
        config = JSON.parse(component.chart_config)
        expect(config["data"]["datasets"].first["borderColor"]).to eq("rgb(34, 197, 94)")
        expect(config["data"]["datasets"].first["backgroundColor"]).to eq("rgba(34, 197, 94, 0.1)")
      end
    end
  end

  describe "scheme colors in #chart_config" do
    subject(:options) { JSON.parse(described_class.new(title: "Chart", type: type, data: [1], labels: ["A"]).chart_config)["options"] }

    let(:grid) { "rgba(228, 228, 231, 1)" }
    let(:text) { "rgb(113, 113, 122)" }

    context "with a cartesian chart" do
      let(:type) { :bar }

      it "colors the grid lines of both axes" do
        expect(options["scales"].values_at("x", "y").map { |axis| axis["grid"]["color"] }).to eq([grid, grid])
      end

      it "colors the axis borders" do
        expect(options["scales"].values_at("x", "y").map { |axis| axis["border"]["color"] }).to eq([grid, grid])
      end

      it "colors the ticks of both axes" do
        expect(options["scales"].values_at("x", "y").map { |axis| axis["ticks"]["color"] }).to eq([text, text])
      end

      it "colors the legend labels" do
        expect(options["plugins"]["legend"]["labels"]["color"]).to eq(text)
      end
    end

    context "with a radial chart" do
      let(:type) { :radar }

      it "colors the grid and angle lines" do
        expect(options["scales"]["r"].values_at("grid", "angleLines").pluck("color")).to eq([grid, grid])
      end

      it "colors the point labels and ticks" do
        expect([options["scales"]["r"]["pointLabels"]["color"], options["scales"]["r"]["ticks"]["color"]]).to eq([text, text])
      end

      it "draws the ticks without a backdrop, which would stay white in dark themes" do
        expect(options["scales"]["r"]["ticks"]["backdropColor"]).to eq("transparent")
      end
    end

    context "with a pie chart" do
      let(:type) { :pie }

      it "adds no scales, which would draw axes" do
        expect(options).not_to have_key("scales")
      end

      it "colors the legend labels" do
        expect(options["plugins"]["legend"]["labels"]["color"]).to eq(text)
      end
    end

    context "with a dark theme for the request" do
      let(:type) { :line }

      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:midnight) do |t|
          t.chart_grid_color = "rgba(63, 63, 70, 1)"
          t.chart_text_color = "rgb(161, 161, 170)"
        end
      end

      it "uses that theme's grid color" do
        expect(options["scales"]["x"]["grid"]["color"]).to eq("rgba(63, 63, 70, 1)")
      end

      it "uses that theme's text color" do
        expect(options["scales"]["y"]["ticks"]["color"]).to eq("rgb(161, 161, 170)")
      end
    end
  end

  describe "#chart_colors" do
    it "returns theme colors by default" do
      component = described_class.new(title: "Revenue")
      expect(component.chart_colors).to eq(IronAdmin.configuration.theme.chart_colors)
    end

    context "with per-chart colors" do
      it "returns per-chart colors over theme" do
        custom = ["#ff0000", "#00ff00"]
        component = described_class.new(title: "Revenue", colors: custom)
        expect(component.chart_colors).to eq(custom)
      end
    end

    context "with custom theme colors" do
      before do
        IronAdmin.configuration.theme.chart_colors = ["#aaa", "#bbb"]
      end

      it "uses theme colors when no per-chart colors" do
        component = described_class.new(title: "Revenue")
        expect(component.chart_colors).to eq(["#aaa", "#bbb"])
      end

      it "prefers per-chart colors over theme" do
        custom = ["#111", "#222"]
        component = described_class.new(title: "Revenue", colors: custom)
        expect(component.chart_colors).to eq(custom)
      end
    end
  end

  # The dashboard page title is the h1, so a widget title is an h2.
  describe "widget title" do
    subject(:headings) do
      render_inline(described_class.new(title: "Revenue", data: [1], labels: ["Jan"]))
        .css("h1, h2, h3, h4, h5, h6")
    end

    it "is an h2, one level below the page title" do
      expect(headings.map { |heading| [heading.name, heading.text.squish] }).to eq([%w[h2 Revenue]])
    end
  end

  describe "canvas" do
    subject(:canvas) { render_inline(described_class.new(title: "Revenue", data: [1], labels: ["Jan"])).at_css("canvas") }

    it "is an image named after the chart title" do
      expect([canvas[:role], canvas["aria-label"]]).to eq(%w[img Revenue])
    end
  end

  describe "theme classes" do
    subject(:card) { render_inline(described_class.new(title: "Revenue", data: [1], labels: ["Jan"])).at_css("div") }

    context "with the default theme" do
      it "frames the card with the theme's surface, border, radius and shadow" do
        expect(card[:class].split).to include(*%w[bg-white border border-zinc-200 rounded-lg shadow-xs])
      end

      it "titles the card with the theme's card_title" do
        expect(card.at_css("h2")[:class].split).to include(*IronAdmin.current_theme.card_title.split)
      end
    end

    context "with a registered theme active for the request" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:harbor) do |t|
          t.card_bg = "bg-slate-900"
          t.border_width = "border-2"
          t.card_title = "text-base font-bold text-white"
          t.heading_font = "font-serif"
        end
      end

      it "frames the card with that theme's surface and border width" do
        expect(card[:class].split).to include("bg-slate-900", "border-2")
      end

      it "titles the card with that theme's card_title and heading_font" do
        expect(card.at_css("h2")[:class].split).to include(*%w[text-base font-bold text-white font-serif])
      end

      # Tailwind does not guarantee which of two font sizes wins, so only the theme sets one.
      it "leaves the title's size and color to that theme's card_title" do
        expect(card.at_css("h2")[:class].split.grep(/text-/)).to eq(%w[text-base text-white])
      end
    end
  end
end
