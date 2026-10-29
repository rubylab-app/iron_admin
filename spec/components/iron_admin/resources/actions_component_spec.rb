require "rails_helper"
require_relative "../../../../app/components/iron_admin/resources/actions_component"

RSpec.describe IronAdmin::Resources::ActionsComponent, type: :component do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  let(:user) { create(:user) }
  let(:actions) { [{ name: :archive, label: "Archive" }] }

  describe "#initialize" do
    it "stores actions" do
      component = described_class.new(actions: actions, record: user, resource_class: IronAdmin::Resources::UserResource)
      expect(component.actions).to eq(actions)
    end

    it "stores record" do
      component = described_class.new(actions: actions, record: user, resource_class: IronAdmin::Resources::UserResource)
      expect(component.record).to eq(user)
    end

    it "stores resource_class" do
      component = described_class.new(actions: actions, record: user, resource_class: IronAdmin::Resources::UserResource)
      expect(component.resource_class).to eq(IronAdmin::Resources::UserResource)
    end
  end

  describe "#render?" do
    it "returns true when actions exist" do
      component = described_class.new(actions: actions, record: user, resource_class: IronAdmin::Resources::UserResource)
      expect(component.render?).to be true
    end

    it "returns false when actions are empty" do
      component = described_class.new(actions: [], record: user, resource_class: IronAdmin::Resources::UserResource)
      expect(component.render?).to be false
    end
  end

  describe "confirmation" do
    def rendered_button(action)
      render_inline(described_class.new(actions: [action], record: user, resource_class: IronAdmin::Resources::UserResource))
        .at_css("button")
    end

    it "asks with the action's confirm_message" do
      button = rendered_button({ name: :suspend, confirm: true, confirm_message: "Suspend this user?" })

      expect(button["data-turbo-confirm"]).to eq("Suspend this user?")
    end

    it "asks with iron_admin.resources.action.confirm when the action has no confirm_message" do
      allow(I18n).to receive(:t).and_call_original
      allow(I18n).to receive(:t).with("iron_admin.resources.action.confirm").and_return("Run this action?")

      expect(rendered_button({ name: :suspend, confirm: true })["data-turbo-confirm"]).to eq("Run this action?")
    end

    it "does not ask when the action does not request confirmation" do
      button = rendered_button({ name: :suspend })

      expect(button["data-turbo-confirm"]).to be_nil
    end
  end

  describe "an action with form fields" do
    subject(:rendered) do
      render_inline(described_class.new(actions: [form_action, { name: :lock }], record: user,
                                        resource_class: IronAdmin::Resources::UserResource))
    end

    let(:form_action) do
      { name: :suspend, icon: "pause", confirm: true, form_fields: [IronAdmin::ActionField.new(name: :reason)] }
    end
    let(:form_path) { IronAdmin::Engine.routes.url_helpers.resource_action_form_path("users", user, :suspend) }
    let(:link) { rendered.at_css("a[href='#{form_path}']") }

    it "links to the action's form" do
      expect(link).to be_present
    end

    it "styles the link as the action buttons" do
      expect(link[:class]).to eq(IronAdmin::Resources::Styles.secondary_button(IronAdmin.current_theme))
    end

    it "draws the action's icon in the link" do
      expect(link.at_css("svg")[:class].split).to include("h-4", "w-4")
    end

    it "labels the link with the action's name" do
      expect(link.text.squish).to eq("Suspend")
    end

    it "leaves the confirmation to the form" do
      expect(link["data-turbo-confirm"]).to be_nil
    end

    it "does not post the action" do
      action_path = IronAdmin::Engine.routes.url_helpers.resource_action_path("users", user, :suspend)
      expect(rendered.at_css("form[action='#{action_path}']")).to be_nil
    end

    it "keeps the direct POST of an action without form fields" do
      action_path = IronAdmin::Engine.routes.url_helpers.resource_action_path("users", user, :lock)
      expect(rendered.at_css("form[action='#{action_path}'] button")).to be_present
    end
  end

  describe "theme" do
    subject(:rendered) do
      render_inline(described_class.new(actions: [{ name: :archive, icon: "archive-box" }], record: user,
                                        resource_class: IronAdmin::Resources::UserResource))
    end

    let(:styles) { IronAdmin::Resources::Styles }
    let(:theme) { IronAdmin.current_theme }

    it "renders the actions in a panel" do
      expect(rendered.at_css("div")[:class].split).to include(*styles.panel(theme).split)
    end

    it "titles the panel with the panel title classes" do
      expect(rendered.at_css("h2")[:class].split).to include(*styles.panel_title(theme).split)
    end

    it "renders each action as a secondary button" do
      expect(rendered.at_css("button")[:class]).to eq(styles.secondary_button(theme))
    end

    it "draws 16px icons" do
      expect(rendered.at_css("button svg")[:class].split).to include("h-4", "w-4")
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
        expect(rendered.at_css("div")[:class].split).to include("bg-zinc-900")
      end

      it "uses that theme's card title" do
        expect(rendered.at_css("h2")[:class].split).to include("text-base", "font-bold", "text-white")
      end

      it "uses that theme's secondary button" do
        expect(rendered.at_css("button")[:class].split).to include("bg-zinc-800", "text-zinc-100")
      end
    end
  end
end
