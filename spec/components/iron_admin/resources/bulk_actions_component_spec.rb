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

  describe "a bulk action with form fields" do
    subject(:rendered) do
      render_inline(described_class.new(actions: [form_action, { name: :lock }],
                                        resource_class: IronAdmin::Resources::UserResource))
    end

    let(:routes) { IronAdmin::Engine.routes.url_helpers }
    let(:form_action) { { name: :suspend, icon: "pause", form_fields: [IronAdmin::ActionField.new(name: :reason)] } }
    let(:form) { rendered.at_css("form[action='#{routes.resource_bulk_action_form_path("users", :suspend)}']") }

    it "opens the action's form with a GET, which carries the ids the bulk-actions controller adds" do
      expect(form[:method]).to eq("get")
    end

    it "lets the bulk-actions controller add the selected ids" do
      expect(form["data-bulk-actions-target"]).to eq("form")
    end

    context "with forgery protection on" do
      around do |example|
        original = ActionController::Base.allow_forgery_protection
        ActionController::Base.allow_forgery_protection = true
        example.run
      ensure
        ActionController::Base.allow_forgery_protection = original
      end

      it "keeps the CSRF token out of the form's URL" do
        expect(form.at_css("input[name=authenticity_token]")).to be_nil
      end

      it "sends the CSRF token with a bulk action without form fields" do
        post_form = rendered.at_css("form[action='#{routes.resource_bulk_action_path("users", :lock)}']")
        expect(post_form.at_css("input[name=authenticity_token]")[:value]).to be_present
      end
    end

    it "styles the button as the other bulk buttons" do
      expect(form.at_css("button")[:class]).to eq(IronAdmin::Resources::Styles.secondary_button(IronAdmin.current_theme))
    end

    it "keeps the direct POST of a bulk action without form fields" do
      expect(rendered.at_css("form[action='#{routes.resource_bulk_action_path("users", :lock)}']")[:method]).to eq("post")
    end
  end

  describe "confirmation" do
    subject(:rendered) do
      render_inline(described_class.new(actions: [
                                          { name: :purge, confirm: true },
                                          { name: :revoke, confirm: true, confirm_message: "Revoke them?" },
                                          { name: :lock },
                                          { name: :suspend, confirm: true, form_fields: [IronAdmin::ActionField.new(name: :reason)] },
                                        ], resource_class: IronAdmin::Resources::UserResource))
    end

    let(:routes) { IronAdmin::Engine.routes.url_helpers }

    def button(path)
      rendered.at_css("form[action='#{path}'] button")
    end

    it "asks before a confirm: true bulk action without form fields runs" do
      expect(button(routes.resource_bulk_action_path("users", :purge))["data-turbo-confirm"])
        .to eq(I18n.t("iron_admin.resources.action.confirm"))
    end

    it "asks with the action's confirm_message" do
      expect(button(routes.resource_bulk_action_path("users", :revoke))["data-turbo-confirm"]).to eq("Revoke them?")
    end

    it "runs a bulk action without confirm without asking" do
      expect(button(routes.resource_bulk_action_path("users", :lock))["data-turbo-confirm"]).to be_nil
    end

    it "opens the form of a bulk action with form fields without asking, since the form asks" do
      expect(button(routes.resource_bulk_action_form_path("users", :suspend))["data-turbo-confirm"]).to be_nil
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

    # Buttons do not shrink, so on a phone the toolbar wraps them instead of overflowing the page.
    it "wraps the toolbar" do
      expect(toolbar[:class].split).to include("flex-wrap")
    end

    it "wraps the row of action buttons" do
      expect(toolbar.at_css("div")[:class].split).to include("flex-wrap")
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
