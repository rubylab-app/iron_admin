# frozen_string_literal: true

require "rails_helper"

# An action with form_fields is reached through its form: a link (or, for a bulk
# action, the bulk bar's GET submission) opens the form, and the form posts to the
# action. Actions without form_fields keep their direct POST.
RSpec.describe "Action form flow", type: :request do
  let(:document) { response.parsed_body }
  let(:theme) { IronAdmin.current_theme }
  let(:styles) { IronAdmin::Resources::Styles }
  let(:license) { create(:license, status: :active) }
  let(:flow_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = License

      def self.name
        "FlowLicenseResource"
      end

      def self.resource_name
        "flow_licenses"
      end

      belongs_to :user, display: :email

      action :annotate, icon: "pencil-square", confirm: true, confirm_message: "Annotate this license?",
                        form_fields: [
                          action_field(:note, type: :textarea, required: true),
                          action_field(:tag, type: :text),
                        ] do |license, params|
        license.update!(license_type: [params[:note], params[:tag]].compact_blank.join(" / "))
      end

      action :relabel, confirm: true, form_fields: [action_field(:tag, type: :text)] do |license, params|
        license.update!(license_type: params[:tag].presence || "unlabeled")
      end

      action :retag, form_fields: [action_field(:tag, type: :text)] do |license, params|
        license.update!(license_type: params[:tag])
      end

      action :expire, icon: "clock", confirm: true do |license|
        license.update!(status: :expired)
      end
    end
  end

  def form_path(action_name, record = license)
    iron_admin.resource_action_form_path("flow_licenses", record, action_name)
  end

  def execute_path(action_name, record = license)
    iron_admin.resource_action_path("flow_licenses", record, action_name)
  end

  before { IronAdmin::ResourceRegistry.register(flow_resource) }

  describe "GET /:resource_name/:id (show page)" do
    subject(:form_link) { document.at_css("a[href='#{form_path(:annotate)}']") }

    before { get iron_admin.resource_path("flow_licenses", license), as: :html }

    it "links an action with form fields to its form" do
      expect(form_link).to be_present
    end

    it "styles the link as the action buttons" do
      expect(form_link[:class]).to eq(styles.secondary_button(theme))
    end

    it "draws the action's icon in the link" do
      expect(form_link.at_css("svg")[:class].split).to include("h-4", "w-4")
    end

    it "labels the link with the action's name" do
      expect(form_link.text.squish).to eq("Annotate")
    end

    it "does not ask for confirmation before showing the form" do
      expect(form_link["data-turbo-confirm"]).to be_nil
    end

    it "does not post an action with form fields from the show page" do
      expect(document.at_css("form[action='#{execute_path(:annotate)}']")).to be_nil
    end

    it "keeps the direct POST of an action without form fields" do
      expect(document.at_css("form[action='#{execute_path(:expire)}'] button")).to be_present
    end

    it "keeps the confirmation of an action without form fields" do
      expect(document.at_css("form[action='#{execute_path(:expire)}'] button")["data-turbo-confirm"]).to eq("Are you sure?")
    end
  end

  describe "GET /:resource_name/:id/actions/:action_name/form" do
    subject(:submit) { document.at_css("form[action='#{execute_path(action_name)}'] button[type=submit]") }

    let(:action_name) { :annotate }

    before { get form_path(action_name), as: :html }

    it "renders the form" do
      expect(response).to have_http_status(:ok)
    end

    it "asks for confirmation on the submit, with the action's confirm_message" do
      expect(submit["data-turbo-confirm"]).to eq("Annotate this license?")
    end

    it "links Cancel to the record" do
      cancel = document.css("a").find { |link| link.text.strip == I18n.t("iron_admin.form.cancel_button") }
      expect(cancel[:href]).to eq(iron_admin.resource_path("flow_licenses", license))
    end

    it "leaves out the ids of a bulk selection" do
      get form_path(action_name), params: { ids: [license.id] }, as: :html
      expect(document.css("input[name='ids[]']")).to be_empty
    end

    context "with confirm and no confirm_message" do
      let(:action_name) { :relabel }

      it "asks with iron_admin.resources.action.confirm" do
        expect(submit["data-turbo-confirm"]).to eq(I18n.t("iron_admin.resources.action.confirm"))
      end
    end

    context "without confirm" do
      let(:action_name) { :retag }

      it "submits without asking" do
        expect(submit["data-turbo-confirm"]).to be_nil
      end
    end
  end

  describe "authorization of GET /:resource_name/:id/actions/:action_name/form" do
    context "with a record outside the tenant scope" do
      let(:outsider) { create(:license) }

      before do
        tenant = license.user
        IronAdmin.configure { |config| config.tenant_scope { |scope| scope.where(user_id: tenant.id) } }
      end

      it "returns not found, as executing the action does" do
        get form_path(:annotate, outsider), as: :html
        expect(response).to have_http_status(:not_found)
      end

      it "renders the form of a record inside the tenant scope" do
        get form_path(:annotate), as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "with an action the policy denies" do
      before do
        flow_resource.class_eval do
          policy do
            allow :read
            deny :annotate
          end
        end
        get iron_admin.resource_path("flow_licenses", license), as: :html
      end

      it "does not link the denied action from the show page" do
        expect(document.at_css("a[href='#{form_path(:annotate)}']")).to be_nil
      end

      it "forbids its form" do
        get form_path(:annotate), as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with an action whose condition fails" do
      before do
        flow_resource.action(:lock, condition: ->(_license) { false },
                                    form_fields: [{ name: :tag, type: :text }]) do |license, _params|
          license.update!(status: :revoked)
        end
        get iron_admin.resource_path("flow_licenses", license), as: :html
      end

      it "does not link the action from the show page" do
        expect(document.at_css("a[href='#{form_path(:lock)}']")).to be_nil
      end

      it "forbids its form" do
        get form_path(:lock), as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
