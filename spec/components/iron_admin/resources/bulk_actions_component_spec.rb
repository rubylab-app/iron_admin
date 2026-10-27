require "rails_helper"
require_relative "../../../../app/components/iron_admin/resources/bulk_actions_component"

RSpec.describe IronAdmin::Resources::BulkActionsComponent, type: :component do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  let(:actions) { [{ name: :archive, label: "Archive Selected" }] }

  describe "#initialize" do
    it "stores actions" do
      component = described_class.new(actions: actions, resource_class: IronAdmin::Resources::UserResource)
      expect(component.actions).to eq(actions)
    end

    it "stores resource_class" do
      component = described_class.new(actions: actions, resource_class: IronAdmin::Resources::UserResource)
      expect(component.resource_class).to eq(IronAdmin::Resources::UserResource)
    end
  end

  describe "#render?" do
    it "returns true when actions exist" do
      component = described_class.new(actions: actions, resource_class: IronAdmin::Resources::UserResource)
      expect(component.render?).to be true
    end

    it "returns false when actions are empty" do
      component = described_class.new(actions: [], resource_class: IronAdmin::Resources::UserResource)
      expect(component.render?).to be false
    end
  end

  describe "theme" do
    subject(:rendered) do
      render_inline(described_class.new(actions: [{ name: :archive, icon: "archive-box" }],
                                        resource_class: IronAdmin::Resources::UserResource))
    end

    let(:toolbar) { rendered.at_css("[data-bulk-actions-target=toolbar]") }

    it "renders the toolbar on the theme's card background with a top border in its card border color" do
      expect(toolbar[:class].split).to include("bg-white", "border-t", "border-zinc-200")
    end

    it "renders each action as a secondary button" do
      expect(rendered.at_css("button[type=submit]")[:class]).to eq(
        IronAdmin::Resources::Styles.secondary_button(IronAdmin.current_theme)
      )
    end

    it "writes the selection count in the theme's muted text color" do
      expect(toolbar.at_css("span")[:class].split).to include("text-zinc-500")
    end

    context "with a registered theme active" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:midnight) do |t|
          t.card_bg = "bg-zinc-900"
          t.card_title = "text-base font-bold text-white"
          t.btn_secondary = "bg-zinc-800 text-zinc-100"
          t.label_transform = "uppercase tracking-wider"
          t.table_frame = "ring-1 ring-zinc-700"
          t.table_cell_padding = "px-3 py-1.5"
        end
      end

      it "uses that theme's card background" do
        expect(toolbar[:class].split).to include("bg-zinc-900")
      end

      it "uses that theme's secondary button" do
        expect(rendered.at_css("button[type=submit]")[:class].split).to include("bg-zinc-800")
      end
    end
  end
end
