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
end
