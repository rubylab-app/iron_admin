require "rails_helper"
require_relative "../../../../app/components/iron_admin/resources/breadcrumb_component"

RSpec.describe IronAdmin::Resources::BreadcrumbComponent, type: :component do
  describe "slots" do
    it "has items slot" do
      expect(described_class.registered_slots).to have_key(:items)
    end
  end

  describe "rendering" do
    subject(:separator) do
      render_inline(described_class.new) do |breadcrumb|
        breadcrumb.with_item(label: "Users", href: "/admin/users")
        breadcrumb.with_item(label: "Ada", current: true)
      end.at_css("svg")
    end

    it "draws the separators in the theme's icon_muted color" do
      expect(separator[:class].split).to include("text-zinc-400")
    end

    it "hides the separators from screen readers" do
      expect(separator["aria-hidden"]).to eq("true")
    end
  end
end

RSpec.describe IronAdmin::Resources::BreadcrumbComponent::ItemComponent, type: :component do
  describe "#initialize" do
    it "stores label" do
      component = described_class.new(label: "Users")
      expect(component.label).to eq("Users")
    end

    it "defaults href to nil" do
      component = described_class.new(label: "Users")
      expect(component.href).to be_nil
    end

    it "defaults current to false" do
      component = described_class.new(label: "Users")
      expect(component.current).to be false
    end

    it "accepts all options" do
      component = described_class.new(label: "Users", href: "/admin/users", current: true)
      expect(component.href).to eq("/admin/users")
      expect(component.current).to be true
    end
  end

  describe "#item_classes" do
    it "includes text-sm" do
      component = described_class.new(label: "Users")
      expect(component.item_classes).to include("text-sm")
    end

    it "includes font-medium when current" do
      component = described_class.new(label: "Users", current: true)
      expect(component.item_classes).to include("font-medium")
    end

    it "writes the current page in the theme's body text color" do
      component = described_class.new(label: "Users", current: true)
      expect(component.item_classes.split).to include("text-zinc-900")
    end

    it "mutes the links with the theme's link_muted classes" do
      component = described_class.new(label: "Users", href: "/admin/users")
      expect(component.item_classes.split).to include("text-zinc-500", "hover:text-zinc-900")
    end

    it "outlines a focused link with the theme's focus_ring" do
      component = described_class.new(label: "Users", href: "/admin/users")
      expect(component.item_classes.split).to include("focus-visible:outline-indigo-500")
    end

    context "with a registered theme active" do
      before do
        IronAdmin::RequestContext.theme = IronAdmin.configuration.register_theme(:midnight) do |t|
          t.link_muted = "text-zinc-400 hover:text-white"
        end
      end

      it "mutes the links with that theme's link_muted classes" do
        expect(described_class.new(label: "Users", href: "/admin/users").item_classes.split).to include("text-zinc-400")
      end
    end
  end

  describe "#call" do
    it "renders a link when href is present and not current" do
      result = render_inline(described_class.new(label: "Users", href: "/admin/users"))
      expect(result.css("a[href='/admin/users']")).to be_present
      expect(result.css("a").text).to eq("Users")
    end

    it "renders a span when current" do
      result = render_inline(described_class.new(label: "Edit", current: true))
      expect(result.css("span")).to be_present
      expect(result.css("span[aria-current='page']")).to be_present
    end

    it "renders a span when no href" do
      result = render_inline(described_class.new(label: "Details"))
      expect(result.css("span")).to be_present
    end
  end
end
