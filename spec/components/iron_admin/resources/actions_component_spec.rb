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

    it "asks with the default message when the action has no confirm_message" do
      button = rendered_button({ name: :suspend, confirm: true })

      expect(button["data-turbo-confirm"]).to eq("Are you sure?")
    end

    it "does not ask when the action does not request confirmation" do
      button = rendered_button({ name: :suspend })

      expect(button["data-turbo-confirm"]).to be_nil
    end
  end
end
