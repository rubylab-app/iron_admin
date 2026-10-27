require "rails_helper"
require_relative "../../../../app/components/iron_admin/ui/empty_state_component"

RSpec.describe IronAdmin::Ui::EmptyStateComponent, type: :component do
  describe "#initialize" do
    it "has default title" do
      component = described_class.new
      expect(component.title).to eq("No results found")
    end

    it "has default icon" do
      component = described_class.new
      expect(component.icon).to eq("inbox")
    end

    it "accepts custom title" do
      component = described_class.new(title: "No users")
      expect(component.title).to eq("No users")
    end

    it "accepts description" do
      component = described_class.new(description: "Create your first user")
      expect(component.description).to eq("Create your first user")
    end

    it "accepts action_text and action_href" do
      component = described_class.new(action_text: "Create", action_href: "/new")
      expect(component.action_text).to eq("Create")
      expect(component.action_href).to eq("/new")
    end
  end

  describe "#has_action?" do
    it "returns true when both action_text and action_href are present" do
      component = described_class.new(action_text: "Create", action_href: "/new")
      expect(component.has_action?).to be true
    end

    it "returns false when action_text is missing" do
      component = described_class.new(action_href: "/new")
      expect(component.has_action?).to be false
    end

    it "returns false when action_href is missing" do
      component = described_class.new(action_text: "Create")
      expect(component.has_action?).to be false
    end
  end

  describe "rendering" do
    subject(:rendered) { render_inline(component) }

    let(:component) { described_class.new(title: "No users yet", action_text: "New user", action_href: "/admin/users/new") }
    let(:icon_tile) { rendered.at_css("div > div")[:class].split }

    context "with the default theme" do
      it "sets the icon on the theme's muted surface" do
        expect(icon_tile).to include("bg-zinc-50", "border", "border-zinc-200", "rounded-lg")
      end

      it "titles the state with the theme's card_title" do
        expect(rendered.at_css("h3")[:class].split).to include("text-sm", "font-semibold", "text-zinc-900")
      end

      it "renders the action as a primary button" do
        expect(rendered.at_css("a[href='/admin/users/new']")[:class].split).to include("h-9", "bg-zinc-900", "rounded-md")
      end
    end

    context "with a registered theme active" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:midnight) do |t|
          t.surface_muted = "bg-zinc-800"
        end
      end

      it "sets the icon on that theme's muted surface" do
        expect(icon_tile).to include("bg-zinc-800")
      end
    end
  end
end
