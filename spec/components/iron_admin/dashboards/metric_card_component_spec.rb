require "rails_helper"
require_relative "../../../../app/components/iron_admin/dashboards/metric_card_component"

RSpec.describe IronAdmin::Dashboards::MetricCardComponent, type: :component do
  it "renders metric name and value" do
    result = render_inline(described_class.new(name: :total_users, value: 42, format: :number))

    expect(result.text).to include("Total users")
    expect(result.text).to include("42")
  end

  it "formats currency" do
    result = render_inline(described_class.new(name: :revenue, value: 1500.50, format: :currency))

    expect(result.text).to include("$1,500.50")
  end

  it "exposes icon attribute when provided" do
    component = described_class.new(name: :total_users, value: 42, format: :number, icon: "users")
    expect(component.icon).to eq("users")
  end

  it "has nil icon when not provided" do
    component = described_class.new(name: :total_users, value: 42, format: :number)
    expect(component.icon).to be_nil
  end

  it "renders the heroicon when icon is provided" do
    result = render_inline(described_class.new(name: :total_users, value: 42, format: :number, icon: "users"))

    expect(result.css("svg").size).to eq(1)
  end

  it "adds a stable target id when live rendering is enabled" do
    result = render_inline(described_class.new(name: :total_users, value: 42, format: :number, live: true))

    expect(result.css("#metric_total_users").size).to eq(1)
  end

  it "omits the id attribute when live rendering is disabled" do
    result = render_inline(described_class.new(name: :total_users, value: 42, format: :number))

    expect(result.css("[id]").map(&:name)).to be_empty
  end

  context "with an icon next to the label" do
    subject(:card) do
      render_inline(described_class.new(name: :monthly_revenue, value: 123_456.78, format: :currency, icon: "banknotes"))
    end

    let(:label) { card.css("p").find { |paragraph| paragraph.text.strip == "Monthly revenue" } }
    let(:value) { card.css("p").find { |paragraph| paragraph.text.strip == "$123,456.78" } }

    it "lets the label wrap instead of pushing against the icon" do
      expect(label[:class].to_s.split).to include("min-w-0")
    end

    it "keeps a gap between the label and the icon" do
      expect(label.parent[:class].to_s.split).to include(a_string_matching(/\Agap-\d+\z/))
    end

    # A narrow card would otherwise split "$123,456.78" across two lines.
    it "never breaks the value inside the number" do
      classes = [value, *value.ancestors("[class]")].flat_map { |node| node[:class].split }

      expect(classes).not_to include("break-words")
    end

    it "puts the value on its own row, below the label and the icon" do
      expect(label.parent.css("p")).not_to include(value)
    end
  end

  describe "theme classes" do
    subject(:card) { render_inline(described_class.new(name: :total_users, value: 1284, icon: "users")).at_css("div") }

    let(:theme) { IronAdmin.current_theme }
    let(:label) { card.css("p").find { |paragraph| paragraph.text.strip == "Total users" } }
    let(:value) { card.css("p").find { |paragraph| paragraph.text.strip == "1,284" } }
    let(:tile) { card.at_css("svg").parent }

    context "with the default theme" do
      it "frames the card with the theme's surface, border, radius and shadow" do
        expect(card[:class].split).to include(*%w[bg-white border border-zinc-200 rounded-lg shadow-xs])
      end

      it "puts the label on top in the theme's metric_label" do
        expect(label[:class].split).to include(*theme.metric_label.split)
      end

      it "shows the figure in tabular numbers" do
        expect(value[:class].split).to include("tabular-nums")
      end

      it "draws the icon tile in the theme's metric_icon" do
        expect(tile[:class].split).to include(*theme.metric_icon.split, theme.control_radius)
      end
    end

    context "with a registered theme active for the request" do
      before do
        IronAdmin::RequestContext.theme = IronAdmin.configuration.register_theme(:harbor) do |t|
          t.card_bg = "bg-slate-900"
          t.border_width = "border-2"
          t.metric_label = "text-sm font-bold text-slate-300"
          t.label_transform = "uppercase tracking-widest"
          t.metric_value = "text-4xl font-black text-white"
          t.metric_icon = "bg-sky-500/10 text-sky-300"
        end
      end

      it "frames the card with that theme's surface and border width" do
        expect(card[:class].split).to include("bg-slate-900", "border-2")
      end

      it "styles the label with that theme's metric_label and label_transform" do
        expect(label[:class].split).to include(*%w[text-sm font-bold text-slate-300 uppercase tracking-widest])
      end

      # Tailwind does not guarantee which of two font sizes wins, so only the theme sets one.
      it "leaves the figure's size and color to that theme's metric_value" do
        expect(value[:class].split.grep(/text-/)).to eq(%w[text-4xl text-white])
      end

      it "draws the icon tile in that theme's metric_icon" do
        expect(tile[:class].split).to include("bg-sky-500/10", "text-sky-300")
      end
    end
  end
end
