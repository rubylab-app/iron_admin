require "rails_helper"
require_relative "../../../../app/components/iron_admin/dashboards/quick_links_component"

RSpec.describe IronAdmin::Dashboards::QuickLinksComponent, type: :component do
  describe "#initialize" do
    it "defaults title to 'Quick Links'" do
      component = described_class.new
      expect(component.title).to eq("Quick Links")
    end

    it "accepts custom title" do
      component = described_class.new(title: "Shortcuts")
      expect(component.title).to eq("Shortcuts")
    end
  end

  describe "#render?" do
    it "returns true when links exist" do
      component = described_class.new
      allow(component).to receive(:links).and_return([double])
      expect(component.render?).to be true
    end

    it "returns false when links are empty" do
      component = described_class.new
      allow(component).to receive(:links).and_return([])
      expect(component.render?).to be false
    end
  end

  describe "slots" do
    it "has links slot" do
      expect(described_class.registered_slots).to have_key(:links)
    end
  end

  # The dashboard page title is the h1, so a widget title is an h2.
  describe "widget title" do
    subject(:headings) do
      render_inline(described_class.new(title: "Shortcuts")) { |links| links.with_link(label: "Users", href: "/admin/users") }
        .css("h1, h2, h3, h4, h5, h6")
    end

    before do
      vc_test_controller.view_context.class.define_method(:heroicon) do |name, **_opts|
        "<svg class=\"heroicon-#{name}\"></svg>".html_safe
      end
    end

    it "is an h2, one level below the page title" do
      expect(headings.map { |heading| [heading.name, heading.text.squish] }).to eq([%w[h2 Shortcuts]])
    end
  end
end

RSpec.describe IronAdmin::Dashboards::QuickLinksComponent::LinkComponent, type: :component do
  describe "#initialize" do
    it "stores label" do
      component = described_class.new(label: "Dashboard", href: "/dashboard")
      expect(component.label).to eq("Dashboard")
    end

    it "stores href" do
      component = described_class.new(label: "Dashboard", href: "/dashboard")
      expect(component.href).to eq("/dashboard")
    end

    it "defaults icon to nil" do
      component = described_class.new(label: "Dashboard", href: "/dashboard")
      expect(component.icon).to be_nil
    end

    it "defaults description to nil" do
      component = described_class.new(label: "Dashboard", href: "/dashboard")
      expect(component.description).to be_nil
    end

    it "accepts all options" do
      component = described_class.new(
        label: "Users",
        href: "/admin/users",
        icon: "users",
        description: "Manage user accounts"
      )
      expect(component.label).to eq("Users")
      expect(component.href).to eq("/admin/users")
      expect(component.icon).to eq("users")
      expect(component.description).to eq("Manage user accounts")
    end
  end
end
