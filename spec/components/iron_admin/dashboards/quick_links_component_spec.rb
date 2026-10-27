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

  describe "theme classes" do
    subject(:card) do
      render_inline(described_class.new) { |links| links.with_link(label: "Users", href: "/admin/users") }.at_css("div")
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
      it "colors the dividers between links with the theme's table_border" do
        expect(card.at_css("a").parent[:class].split).to include("divide-y", *IronAdmin.current_theme.table_border.split)
      end
    end

    context "with a registered theme active for the request" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:harbor) do |t|
          t.card_bg = "bg-slate-900"
          t.border_width = "border-2"
          t.heading_font = "font-serif"
        end
      end

      it "frames the card with that theme's surface and border width" do
        expect(card[:class].split).to include("bg-slate-900", "border-2")
      end

      it "titles the card with that theme's heading_font" do
        expect(card.at_css("h2")[:class].split).to include("font-serif")
      end
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

  describe "rendering" do
    subject(:link) { render_inline(described_class.new(label: "Users", href: "/admin/users", icon: "users")).at_css("a") }

    let(:theme) { IronAdmin.current_theme }
    let(:icon) { link.css("svg").first }
    let(:chevron) { link.css("svg").last }

    it "highlights the link on hover with the theme's item_hover" do
      expect(link[:class].split).to include(*theme.item_hover.split)
    end

    it "shows the theme's focus ring on the link" do
      expect(link[:class].split).to include(*theme.focus_ring.split)
    end

    it "draws the icon tile in the theme's metric_icon and control_radius" do
      expect(icon.parent[:class].split).to include(*theme.metric_icon.split, theme.control_radius)
    end

    it "draws the chevron in the theme's icon_muted" do
      expect(chevron[:class].split).to include(*theme.icon_muted.split)
    end

    context "with a registered theme active for the request" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:harbor) do |t|
          t.item_hover = "hover:bg-slate-800"
          t.metric_icon = "bg-sky-500/10 text-sky-300"
        end
      end

      it "highlights the link on hover with that theme's item_hover" do
        expect(link[:class].split).to include("hover:bg-slate-800")
      end

      it "draws the icon tile in that theme's metric_icon" do
        expect(icon.parent[:class].split).to include("bg-sky-500/10", "text-sky-300")
      end
    end
  end
end
