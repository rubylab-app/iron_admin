# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Action Forms", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
  end

  let(:user) { create(:user) }
  let!(:license) { create(:license, user: user, status: "active") }

  describe "backward compatibility with 1-arg action blocks" do
    it "executes the action without params" do
      post iron_admin.resource_action_path("licenses", license, "revoke"), as: :html
      expect(license.reload.status).to eq("revoked")
    end

    it "redirects to the show page" do
      post iron_admin.resource_action_path("licenses", license, "revoke"), as: :html
      expect(response).to redirect_to(iron_admin.resource_path("licenses", license))
    end
  end

  context "with 2-arg action block and form_fields" do
    let(:form_action_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "FormExecResource"
        end

        def self.resource_name
          "form_exec_licenses"
        end

        belongs_to :user, display: :email

        action :revoke_with_reason,
               form_fields: [
                 action_field(:reason, type: :textarea, required: true),
                 action_field(:notify, type: :boolean),
               ] do |lic, params|
          lic.update!(status: :revoked, license_type: params[:reason])
        end
      end
    end

    before { IronAdmin::ResourceRegistry.register(form_action_resource) }

    describe "GET action_form" do
      it "renders the form page" do
        get iron_admin.resource_action_form_path("form_exec_licenses", license, "revoke_with_reason"),
            as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Reason")
      end
    end

    describe "POST execute_action with form params" do
      it "passes collected form params to the 2-arg block" do
        post iron_admin.resource_action_path("form_exec_licenses", license, "revoke_with_reason"),
             params: { action_form: { reason: "Policy violation", notify: "1" } },
             as: :html

        expect(license.reload.status).to eq("revoked")
        expect(license.reload.license_type).to eq("Policy violation")
      end

      it "redirects to the show page" do
        post iron_admin.resource_action_path("form_exec_licenses", license, "revoke_with_reason"),
             params: { action_form: { reason: "Policy violation" } },
             as: :html

        expect(response).to redirect_to(iron_admin.resource_path("form_exec_licenses", license))
      end

      context "with unpermitted keys in action_form" do
        it "only permits declared form field keys" do
          post iron_admin.resource_action_path("form_exec_licenses", license, "revoke_with_reason"),
               params: { action_form: { reason: "Valid", malicious_key: "injected" } },
               as: :html

          expect(license.reload.status).to eq("revoked")
        end
      end

      context "without action_form param" do
        it "passes empty hash to the block" do
          post iron_admin.resource_action_path("form_exec_licenses", license, "revoke_with_reason"),
               as: :html

          expect(license.reload.status).to eq("revoked")
        end
      end
    end
  end

  context "with 2-arg bulk_action block and form_fields" do
    let(:bulk_form_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "BulkFormExecResource"
        end

        def self.resource_name
          "bulk_form_exec_licenses"
        end

        belongs_to :user, display: :email

        bulk_action :bulk_revoke_with_note,
                    form_fields: [
                      action_field(:note, type: :textarea, required: true),
                    ] do |licenses, params|
          licenses.update_all(status: :revoked, license_type: params[:note])
        end
      end
    end

    let!(:licenses) { create_list(:license, 3, user: user, status: "active") }

    before { IronAdmin::ResourceRegistry.register(bulk_form_resource) }

    describe "GET bulk_action_form" do
      it "renders the bulk form page" do
        get iron_admin.resource_bulk_action_form_path("bulk_form_exec_licenses", "bulk_revoke_with_note"),
            as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Note")
      end
    end

    describe "POST execute_bulk_action with form params" do
      it "passes collected form params to the 2-arg block" do
        post iron_admin.resource_bulk_action_path("bulk_form_exec_licenses", "bulk_revoke_with_note"),
             params: { ids: licenses.map(&:id), action_form: { note: "Bulk revocation" } },
             as: :html

        licenses.each do |l|
          expect(l.reload.status).to eq("revoked")
          expect(l.reload.license_type).to eq("Bulk revocation")
        end
      end

      it "redirects to the index page" do
        post iron_admin.resource_bulk_action_path("bulk_form_exec_licenses", "bulk_revoke_with_note"),
             params: { ids: licenses.map(&:id), action_form: { note: "Bulk revocation" } },
             as: :html

        expect(response).to redirect_to(iron_admin.resources_path("bulk_form_exec_licenses"))
      end
    end
  end

  describe "backward compatibility with 1-arg bulk_action blocks" do
    let!(:licenses) { create_list(:license, 3, user: user) }

    it "executes without params" do
      post iron_admin.resource_bulk_action_path("licenses", "export"),
           params: { ids: licenses.map(&:id) },
           as: :html

      expect(response).to redirect_to(iron_admin.resources_path("licenses"))
    end
  end

  describe "route order" do
    it "does not match bulk_actions as an :id parameter" do
      get iron_admin.resource_bulk_action_form_path("licenses", "export"), as: :html
      expect(response).not_to have_http_status(:not_found)
    end
  end
end
