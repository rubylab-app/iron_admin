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

    context "when iron_admin.resources.action.confirm is translated" do
      before do
        allow(I18n).to receive(:t).and_call_original
        allow(I18n).to receive(:t).with("iron_admin.resources.action.confirm").and_return("Run this action?")
        get iron_admin.resource_path("show_actions_licenses", license), as: :html
      end

      it "asks with that text instead of the delete confirmation" do
        expect(action_button(:expire)["data-turbo-confirm"]).to eq("Run this action?")
      end
    end

    context "when no member action is offered" do
      let(:show_actions_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "NoOfferedActionsLicenseResource"
          end

          def self.resource_name
            "show_actions_licenses"
          end

          action(:renew, condition: ->(_license) { false }) { |license| license.update!(status: :active) }
        end
      end

      it "does not render the Actions card" do
        expect(response.parsed_body.css("h2").map { |heading| heading.text.strip }).not_to include("Actions")
      end
    end
  end

  describe "has_many related list" do
    let!(:license) { create(:license, user: user) }
    let!(:other_license) { create(:license) }

    def view_all_link
      response.parsed_body.css("a").find { |link| link.text.strip == "View all" }
    end

    it "wraps the related records table in a horizontal scroll container" do
      get iron_admin.resource_path("users", user), as: :html

      license_link = ".overflow-x-auto table a[href='#{iron_admin.resource_path("licenses", license)}']"
      expect(response.parsed_body.css(license_link)).not_to be_empty
    end

    context "when the associated resource has a filter on the foreign key" do
      let(:filtered_license_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "FilteredLicenseResource"
          end

          def self.resource_name
            "licenses"
          end

          filter :user_id, type: :select
        end
      end

      before do
        IronAdmin::ResourceRegistry.register(filtered_license_resource)
        get iron_admin.resource_path("users", user), as: :html
      end

      it "links View all to the index filtered by the parent record" do
        expect(view_all_link["href"]).to eq(iron_admin.resources_path("licenses", filters: { user_id: user.id }))
      end

      it "lists only the parent's records behind the View all link" do
        get view_all_link["href"], as: :html

        expect(response.body).not_to include(other_license.license_key)
      end

      it "keeps the parent's records behind the View all link" do
        get view_all_link["href"], as: :html

        expect(response.body).to include(license.license_key)
      end
    end

    context "when the associated resource has no filter on the foreign key" do
      before { get iron_admin.resource_path("users", user), as: :html }

      it "links View all to the index, which could not apply the filter" do
        expect(view_all_link["href"]).to eq(iron_admin.resources_path("licenses"))
      end
    end
  end

  describe "empty values" do
    subject(:value_cell) do
      get iron_admin.resource_path("users", user), as: :html
      response.parsed_body.css("dl > div").find { |row| row.at_css("dt").text.strip == label }.at_css("dd")
    end

    let(:user) { create(:user, name: "Ada", role: nil) }
    let(:label) { "Role" }

    # A blank cell reads as a value that did not load.
    it "marks an empty value with a dash" do
      expect(value_cell.at_css("[aria-hidden=true]").text).to eq("\u2014")
    end

    it "mutes the dash with the theme's muted_text" do
      expect(value_cell.at_css("[aria-hidden=true]")[:class].split).to include(*IronAdmin.current_theme.muted_text.split)
    end

    it "names the empty value for screen readers" do
      expect(value_cell.at_css(".sr-only").text).to eq(I18n.t("iron_admin.fields.empty_value"))
    end

    context "with a value" do
      let(:label) { "Name" }

      it "shows the value" do
        expect(value_cell.text.strip).to eq("Ada")
      end
    end

    context "with a false boolean" do
      let(:user) { create(:user, active: false) }
      let(:label) { "Active" }

      it "shows the false icon, not the dash" do
        expect(value_cell.at_css(".sr-only").text).to eq(I18n.t("iron_admin.fields.boolean_false"))
      end
    end
  end
end
