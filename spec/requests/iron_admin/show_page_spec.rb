# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Resource show page", type: :request do
  let(:user) { create(:user) }

  describe "member action buttons" do
    let(:license) { create(:license, user: user) }
    let(:show_actions_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "ShowActionsLicenseResource"
        end

        def self.resource_name
          "show_actions_licenses"
        end

        action :suspend, confirm: true, confirm_message: "Suspend this license?" do |license|
          license.update!(status: :revoked)
        end

        action :expire, confirm: true do |license|
          license.update!(status: :expired)
        end

        action :renew do |license|
          license.update!(status: :active)
        end

        action :purge do |license|
          license.update!(status: :revoked, license_type: "purged")
        end

        policy do
          allow :read
          deny :purge
        end
      end
    end

    def action_button(action_name)
      action_path = iron_admin.resource_action_path("show_actions_licenses", license, action_name)
      response.parsed_body.at_css("form[action='#{action_path}'] button")
    end

    before do
      IronAdmin::ResourceRegistry.register(show_actions_resource)
      get iron_admin.resource_path("show_actions_licenses", license), as: :html
    end

    it "asks for confirmation with the action's confirm_message" do
      expect(action_button(:suspend)["data-turbo-confirm"]).to eq("Suspend this license?")
    end

    it "asks for the default confirmation when the action has no confirm_message" do
      expect(action_button(:expire)["data-turbo-confirm"]).to eq("Are you sure?")
    end

    it "does not ask for confirmation when the action does not request one" do
      expect(action_button(:renew)["data-turbo-confirm"]).to be_nil
    end

    it "offers an action the policy allows" do
      expect(action_button(:renew)).not_to be_nil
    end

    it "does not offer an action the policy denies" do
      expect(action_button(:purge)).to be_nil
    end
  end
end
