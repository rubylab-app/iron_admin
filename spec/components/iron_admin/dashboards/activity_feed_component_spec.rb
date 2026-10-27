require "rails_helper"
require_relative "../../../../app/components/iron_admin/dashboards/activity_feed_component"

RSpec.describe IronAdmin::Dashboards::ActivityFeedComponent, type: :component do
  describe "#initialize" do
    it "defaults title to 'Recent Activity'" do
      component = described_class.new
      expect(component.title).to eq("Recent Activity")
    end

    it "accepts custom title" do
      component = described_class.new(title: "Latest Events")
      expect(component.title).to eq("Latest Events")
    end
  end

  describe "#render?" do
    it "returns true when items exist" do
      component = described_class.new
      allow(component).to receive(:items).and_return([double])
      expect(component.render?).to be true
    end

    it "returns false when items are empty" do
      component = described_class.new
      allow(component).to receive(:items).and_return([])
      expect(component.render?).to be false
    end
  end

  describe "slots" do
    it "has items slot" do
      expect(described_class.registered_slots).to have_key(:items)
    end
  end

  # The dashboard page title is the h1, so a widget title is an h2.
  describe "widget title" do
    subject(:headings) do
      render_inline(described_class.new(title: "Latest Events")) { |feed| feed.with_item(description: "User signed up", timestamp: "now") }
        .css("h1, h2, h3, h4, h5, h6")
    end

    before do
      vc_test_controller.view_context.class.define_method(:heroicon) do |name, **_opts|
        "<svg class=\"heroicon-#{name}\"></svg>".html_safe
      end
    end

    it "is an h2, one level below the page title" do
      expect(headings.map { |heading| [heading.name, heading.text.squish] }).to eq([["h2", "Latest Events"]])
    end
  end

  describe "theme classes" do
    subject(:card) do
      render_inline(described_class.new) { |feed| feed.with_item(description: "User signed up", timestamp: "now") }.at_css("div")
    end

    before do
      vc_test_controller.view_context.class.define_method(:heroicon) do |name, **_opts|
        "<svg class=\"heroicon-#{name}\"></svg>".html_safe
      end
    end

    context "with the default theme" do
      # HAML's dot syntax reads ".py-3.5" as the classes "py-3" and "5".
      it "keeps fractional sizes such as py-3.5 whole" do
        expect(card.css("[class]").flat_map { |node| node[:class].split }).not_to include(match(/\A\d+\z/))
      end

      it "frames the card with the theme's surface, border, radius and shadow" do
        expect(card[:class].split).to include(*%w[bg-white border border-zinc-200 rounded-lg shadow-xs])
      end

      it "titles the card with the theme's card_title" do
        expect(card.at_css("h2")[:class].split).to include(*IronAdmin.current_theme.card_title.split)
      end

      # A border color on the list would leave the dividers in currentColor.
      it "colors the dividers between items with the theme's table_border" do
        expect(card.at_css("ul")[:class].split).to include("divide-y", *IronAdmin.current_theme.table_border.split)
      end
    end

    context "with a registered theme active for the request" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:harbor) do |t|
          t.border_width = "border-2"
          t.card_title = "text-base font-bold text-white"
          t.table_border = "divide-slate-700"
        end
      end

      it "frames the card with that theme's border width" do
        expect(card[:class].split).to include("border-2")
      end

      it "titles the card with that theme's card_title" do
        expect(card.at_css("h2")[:class].split).to include(*%w[text-base font-bold text-white])
      end

      it "colors the dividers with that theme's table_border" do
        expect(card.at_css("ul")[:class].split).to include("divide-slate-700")
      end
    end
  end
end

RSpec.describe IronAdmin::Dashboards::ActivityFeedComponent::ItemComponent, type: :component do
  describe "#initialize" do
    it "stores description" do
      component = described_class.new(description: "User created", timestamp: Time.current)
      expect(component.description).to eq("User created")
    end

    it "stores timestamp" do
      time = Time.current
      component = described_class.new(description: "User created", timestamp: time)
      expect(component.timestamp).to eq(time)
    end

    it "defaults icon to 'circle-stack'" do
      component = described_class.new(description: "Event", timestamp: Time.current)
      expect(component.icon).to eq("circle-stack")
    end

    it "defaults icon_color to blue" do
      component = described_class.new(description: "Event", timestamp: Time.current)
      expect(component.icon_color).to eq(:blue)
    end

    it "defaults href to nil" do
      component = described_class.new(description: "Event", timestamp: Time.current)
      expect(component.href).to be_nil
    end

    it "accepts all options" do
      component = described_class.new(
        description: "User deleted",
        timestamp: "Yesterday",
        icon: "trash",
        icon_color: :red,
        href: "/users/1"
      )
      expect(component.icon).to eq("trash")
      expect(component.icon_color).to eq(:red)
      expect(component.href).to eq("/users/1")
    end
  end

  describe "#icon_classes" do
    subject(:icon_classes) { described_class.new(description: "Event", timestamp: Time.current, icon_color: icon_color).icon_classes.split }

    let(:theme) { IronAdmin.current_theme }

    context "with a color of the theme's badge palette" do
      let(:icon_color) { :green }

      it "tints the icon tile like a badge of that color" do
        expect(icon_classes).to include(*theme.badge_palette[:green].split)
      end

      it "rounds the tile with the theme's control_radius" do
        expect(icon_classes).to include(theme.control_radius)
      end
    end

    context "with a color the old fixed palette did not have" do
      let(:icon_color) { :purple }

      it "tints the icon tile like a badge of that color" do
        expect(icon_classes).to include(*theme.badge_palette[:purple].split)
      end
    end

    context "with an unknown color" do
      let(:icon_color) { :unknown }

      it "falls back to the gray badge colors" do
        expect(icon_classes).to include(*theme.badge_palette[:gray].split)
      end
    end

    context "with a registered theme active for the request" do
      let(:icon_color) { :red }

      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:harbor) do |t|
          t.badge_palette = t.badge_palette.merge(red: "bg-rose-950 text-rose-200")
        end
      end

      it "tints the icon tile with that theme's badge palette" do
        expect(icon_classes).to include("bg-rose-950", "text-rose-200")
      end
    end

    context "with a theme whose badge palette has no gray" do
      let(:icon_color) { :unknown }

      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:harbor) { |t| t.badge_palette = {} }
      end

      it "keeps only the tile radius" do
        expect(icon_classes).to eq([IronAdmin.current_theme.control_radius])
      end
    end
  end

  describe "#formatted_timestamp" do
    it "formats Time objects" do
      time = Time.zone.local(2024, 6, 15, 10, 30)
      component = described_class.new(description: "Event", timestamp: time)
      expect(component.formatted_timestamp).to eq("Jun 15, 10:30")
    end

    it "returns string timestamps as-is" do
      component = described_class.new(description: "Event", timestamp: "Yesterday")
      expect(component.formatted_timestamp).to eq("Yesterday")
    end
  end

  describe "rendering" do
    subject(:item) { render_inline(described_class.new(description: "User signed up", timestamp: "Yesterday", href: href)) }

    before do
      vc_test_controller.view_context.class.define_method(:heroicon) do |name, **_opts|
        "<svg class=\"heroicon-#{name}\"></svg>".html_safe
      end
    end

    context "with an href" do
      let(:href) { "/admin/users/1" }

      it "wraps the icon, description and time in a link to the href" do
        expect(item.at_css("li > a[href='/admin/users/1']")&.text&.squish).to eq("User signed up Yesterday")
      end

      it "highlights the link on hover with the theme's item_hover" do
        expect(item.at_css("a")[:class].split).to include(*IronAdmin.current_theme.item_hover.split)
      end

      it "shows the theme's focus ring on the link" do
        expect(item.at_css("a")[:class].split).to include(*IronAdmin.current_theme.focus_ring.split)
      end
    end

    context "without an href" do
      let(:href) { nil }

      it "shows the description and time" do
        expect(item.at_css("li")&.text&.squish).to eq("User signed up Yesterday")
      end

      it "renders no link" do
        expect(item.css("a")).to be_empty
      end

      it "adds no hover to a row that leads nowhere" do
        expect(item.at_css("li > div")[:class].split).not_to include(*IronAdmin.current_theme.item_hover.split)
      end
    end
  end
end
