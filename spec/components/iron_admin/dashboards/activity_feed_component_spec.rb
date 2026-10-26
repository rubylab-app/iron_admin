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
    it "returns green classes for green color" do
      component = described_class.new(description: "Event", timestamp: Time.current, icon_color: :green)
      expect(component.icon_classes).to include("bg-green-100")
      expect(component.icon_classes).to include("text-green-600")
    end

    it "returns red classes for red color" do
      component = described_class.new(description: "Event", timestamp: Time.current, icon_color: :red)
      expect(component.icon_classes).to include("bg-red-100")
      expect(component.icon_classes).to include("text-red-600")
    end

    it "returns blue classes for blue color" do
      component = described_class.new(description: "Event", timestamp: Time.current, icon_color: :blue)
      expect(component.icon_classes).to include("bg-blue-100")
      expect(component.icon_classes).to include("text-blue-600")
    end

    it "returns yellow classes for yellow color" do
      component = described_class.new(description: "Event", timestamp: Time.current, icon_color: :yellow)
      expect(component.icon_classes).to include("bg-yellow-100")
    end

    it "falls back to gray for unknown color" do
      component = described_class.new(description: "Event", timestamp: Time.current, icon_color: :unknown)
      expect(component.icon_classes).to include("bg-gray-100")
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
    end

    context "without an href" do
      let(:href) { nil }

      it "shows the description and time" do
        expect(item.at_css("li")&.text&.squish).to eq("User signed up Yesterday")
      end

      it "renders no link" do
        expect(item.css("a")).to be_empty
      end
    end
  end
end
