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

    it "offers an action the policy allows" do
      expect(action_button(:renew)).not_to be_nil
    end

    it "does not offer an action the policy denies" do
      expect(action_button(:purge)).to be_nil
    end
  end
end
