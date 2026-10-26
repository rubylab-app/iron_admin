require "rails_helper"
require_relative "../../../../app/components/iron_admin/dashboards/stats_grid_component"

RSpec.describe IronAdmin::Dashboards::StatsGridComponent, type: :component do
  describe "#initialize" do
    it "defaults columns to 4" do
      component = described_class.new
      expect(component.columns).to eq(4)
    end

    it "accepts custom columns" do
      component = described_class.new(columns: 3)
      expect(component.columns).to eq(3)
    end
  end

  describe "#grid_classes" do
    it "returns 2-column classes" do
      component = described_class.new(columns: 2)
      expect(component.grid_classes).to include("sm:grid-cols-2")
    end

    it "returns 3-column classes" do
      component = described_class.new(columns: 3)
      expect(component.grid_classes).to include("lg:grid-cols-3")
    end

    context "with four columns" do
      subject(:grid_classes) { described_class.new(columns: 4).grid_classes.split }

      # From lg the static sidebar leaves the page about 700px, too narrow for four cards.
      it "keeps two columns at the lg breakpoint" do
        expect(grid_classes).not_to include("lg:grid-cols-4")
      end

      it "switches to four columns at the xl breakpoint, as the dashboard's metric grid does" do
        expect(grid_classes).to include("xl:grid-cols-4")
      end
    end

    context "with an unsupported column count" do
      subject(:grid_classes) { described_class.new(columns: 6).grid_classes.split }

      it "falls back to the four-column layout" do
        expect(grid_classes).to eq(described_class.new(columns: 4).grid_classes.split)
      end
    end
  end

  describe "rendered grid" do
    subject(:grid) do
      render_inline(described_class.new) { |component| component.with_stat(label: "Users", value: 1) }.at_css("div")
    end

    it "spaces the cards like the dashboard's metric grid" do
      expect(grid[:class].split).to include("gap-6")
    end
  end

  describe "slots" do
    it "has stats slot" do
      expect(described_class.registered_slots).to have_key(:stats)
    end
  end
end

RSpec.describe IronAdmin::Dashboards::StatsGridComponent::StatComponent, type: :component do
  describe "#initialize" do
    it "requires label and value" do
      component = described_class.new(label: "Users", value: 100)
      expect(component.label).to eq("Users")
      expect(component.value).to eq(100)
    end

    it "defaults change_type to neutral" do
      component = described_class.new(label: "Users", value: 100)
      expect(component.change_type).to eq(:neutral)
    end

    it "accepts change and change_type" do
      component = described_class.new(label: "Users", value: 100, change: "+10%", change_type: :positive)
      expect(component.change).to eq("+10%")
      expect(component.change_type).to eq(:positive)
    end
  end

  describe "#change_classes" do
    it "returns green for positive" do
      component = described_class.new(label: "Users", value: 100, change_type: :positive)
      expect(component.change_classes).to include("green")
    end

    it "returns red for negative" do
      component = described_class.new(label: "Users", value: 100, change_type: :negative)
      expect(component.change_classes).to include("red")
    end
  end

  context "with an icon next to the label" do
    subject(:card) do
      render_inline(described_class.new(label: "Published this month", value: "$123,456.78", change: "+3",
                                        change_type: :positive, icon: "calendar"))
    end

    let(:label) { card.css("p").find { |paragraph| paragraph.text.strip == "Published this month" } }
    let(:value) { card.css("p").find { |paragraph| paragraph.text.strip == "$123,456.78" } }

    it "lets the label wrap instead of pushing against the icon" do
      expect(label[:class].to_s.split).to include("min-w-0")
    end

    it "keeps a gap between the label and the icon" do
      expect(label.parent[:class].to_s.split).to include(a_string_matching(/\Agap-\d+\z/))
    end

    # Next to the icon, a long value such as "$123,456.78" pushed the icon out of a narrow card.
    it "puts the value on its own row, below the label and the icon" do
      expect(label.parent.css("p")).not_to include(value)
    end

    it "never breaks the value inside the number" do
      classes = [value, *value.ancestors("[class]")].flat_map { |node| node[:class].split }

      expect(classes).not_to include("break-words")
    end

    it "uses the metric cards' smaller value size at the xl breakpoint, where four cards share the row" do
      expect(value[:class].split).to include("xl:text-2xl", "2xl:text-3xl")
    end

    it "still renders the change below the value" do
      expect(card.text.squish).to end_with("$123,456.78 +3")
    end
  end

  describe "#change_icon" do
    it "returns trending up for positive" do
      component = described_class.new(label: "Users", value: 100, change_type: :positive)
      expect(component.change_icon).to eq("arrow-trending-up")
    end

    it "returns trending down for negative" do
      component = described_class.new(label: "Users", value: 100, change_type: :negative)
      expect(component.change_icon).to eq("arrow-trending-down")
    end

    it "returns nil for neutral" do
      component = described_class.new(label: "Users", value: 100, change_type: :neutral)
      expect(component.change_icon).to be_nil
    end
  end
end
