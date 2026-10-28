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

      action :purge, form_fields: [action_field(:i_understand, type: :boolean, required: true)] do |license, _params|
        license.update!(license_type: "purged")
      end

      action :review, form_fields: [
        action_field(:tag, type: :text, default: "renewal"),
        action_field(:priority, type: :select, options: %w[low medium high], default: "medium"),
        action_field(:notify_customer, type: :boolean, default: true),
      ] do |license, params|
        license.update!(license_type: params[:tag])
      end

      action :triage, form_fields: [
        action_field(:priority, type: :select, options: %w[low high], required: true),
        action_field(:reason, type: :textarea),
        action_field(:level, type: :select, options: %w[one two]),
        action_field(:notify, type: :boolean),
        action_field(:escalate, type: :boolean, default: true),
        action_field(:count, type: :number),
        action_field(:due_on, type: :date),
        action_field(:due_at, type: :datetime),
      ] do |license, params|
        license.update!(license_type: params[:priority])
      end

      bulk_action :bulk_annotate, icon: "pencil-square", confirm: true,
                                  form_fields: [action_field(:note, type: :textarea, required: true)] do |licenses, params|
        licenses.update_all(license_type: params[:note])
      end

      bulk_action :bulk_review, form_fields: [
        action_field(:note, type: :textarea, required: true),
        action_field(:tag, type: :text, default: "renewal"),
        action_field(:notify_customer, type: :boolean, default: true),
      ] do |licenses, params|
        licenses.update_all(license_type: params[:note])
      end

      bulk_action :bulk_expire, icon: "clock" do |licenses|
        licenses.update_all(status: License.statuses[:expired])
      end

      bulk_action :bulk_purge, confirm: true do |licenses|
        licenses.update_all(license_type: "purged")
      end

      bulk_action :bulk_revoke, confirm: true, confirm_message: "Revoke these licenses?" do |licenses|
        licenses.update_all(status: License.statuses[:revoked])
      end
    end
  end

  def form_path(action_name, record = license)
    iron_admin.resource_action_form_path("flow_licenses", record, action_name)
  end

  def execute_path(action_name, record = license)
    iron_admin.resource_action_path("flow_licenses", record, action_name)
  end

  def bulk_form_path(action_name, **)
    iron_admin.resource_bulk_action_form_path("flow_licenses", action_name, **)
  end

  def bulk_execute_path(action_name)
    iron_admin.resource_bulk_action_path("flow_licenses", action_name)
  end

  def hidden_fields(form)
    form.css("input[type=hidden]").reject { |input| input[:name] == "authenticity_token" }
      .map { |input| [input[:name], input[:value]] }
  end

  def cancel_link
    document.css("a").find { |link| link.text.strip == I18n.t("iron_admin.form.cancel_button") }
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
      expect(cancel_link[:href]).to eq(iron_admin.resource_path("flow_licenses", license))
    end

    # The form is inside a Turbo frame that the record's page does not have.
    it "opens the record from Cancel as a whole page, outside the form's frame" do
      expect(cancel_link["data-turbo-frame"]).to eq("_top")
    end

    it "leaves out the ids of a bulk selection" do
      get form_path(action_name), params: { ids: [license.id] }, as: :html
      expect(document.css("input[name='ids[]']")).to be_empty
    end

    context "with fields that have defaults" do
      let(:action_name) { :review }

      it "fills a text field with its default" do
        expect(document.at_css("input#action_form_tag")[:value]).to eq("renewal")
      end

      it "selects the default option of a select" do
        expect(document.at_css("select#action_form_priority option[selected]")[:value]).to eq("medium")
      end

      it "checks a boolean whose default is true" do
        expect(document.at_css("input#action_form_notify_customer")[:checked]).to be_present
      end
    end

    context "with a required boolean" do
      let(:action_name) { :purge }

      it "makes the browser ask for its checkbox" do
        expect(document.at_css("input#action_form_i_understand")[:required]).to be_present
      end
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

  describe "GET /:resource_name (bulk bar)" do
    let(:bar_form) { document.at_css("form#bulk-actions-form") }

    def bar_button(formaction)
      bar_form.at_css("button[formaction='#{formaction}']")
    end

    before do
      license
      get iron_admin.resources_path("flow_licenses"), as: :html
    end

    it "submits a bulk action with form fields to its form" do
      expect(bar_button(bulk_form_path(:bulk_annotate))).to be_present
    end

    it "opens that form with a GET, which carries the selected ids" do
      expect(bar_button(bulk_form_path(:bulk_annotate))[:formmethod]).to eq("get")
    end

    it "styles that button as the other bulk buttons" do
      expect(bar_button(bulk_form_path(:bulk_annotate))[:class]).to eq(styles.secondary_button(theme))
    end

    it "does not post a bulk action with form fields from the bar" do
      expect(bar_button(bulk_execute_path(:bulk_annotate))).to be_nil
    end

    it "keeps the direct POST of a bulk action without form fields" do
      expect(bar_button(bulk_execute_path(:bulk_expire))[:formmethod]).to be_nil
    end

    it "asks for confirmation before a confirm: true bulk action without form fields runs" do
      expect(bar_button(bulk_execute_path(:bulk_purge))["data-turbo-confirm"]).to eq(I18n.t("iron_admin.resources.action.confirm"))
    end

    it "asks with the bulk action's confirm_message" do
      expect(bar_button(bulk_execute_path(:bulk_revoke))["data-turbo-confirm"]).to eq("Revoke these licenses?")
    end

    it "runs a bulk action without confirm without asking" do
      expect(bar_button(bulk_execute_path(:bulk_expire))["data-turbo-confirm"]).to be_nil
    end

    it "opens the form of a confirm: true bulk action with form fields without asking, since the form asks" do
      expect(bar_button(bulk_form_path(:bulk_annotate))["data-turbo-confirm"]).to be_nil
    end

    it "leaves the CSRF token out of a GET submission, so it stays out of the URL" do
      expect(bar_form["data-action"]).to eq("submit->cp-bulk-select#omitTokenFromGet")
    end
  end

  describe "GET /:resource_name/bulk_actions/:action_name/form" do
    subject(:form) { document.at_css("form[action='#{bulk_execute_path(:bulk_annotate)}']") }

    let(:licenses) { create_list(:license, 2, status: :active) }
    let(:ids) { licenses.map { |selected| selected.id.to_s } }
    let(:state) { { "sort" => "license_key", "direction" => "desc", "page" => "2" } }

    before { get bulk_form_path(:bulk_annotate), params: state.merge("ids" => ids), as: :html }

    it "renders the form" do
      expect(response).to have_http_status(:ok)
    end

    it "says how many records the action applies to" do
      expect(form.text.squish).to include(I18n.t("iron_admin.resources.bulk_action_form.selected", count: 2))
    end

    it "carries the selected ids and the index state to the action" do
      expect(hidden_fields(form)).to contain_exactly(
        ["ids[]", ids.first], ["ids[]", ids.last], *state.to_a
      )
    end

    it "asks for confirmation on the submit" do
      expect(form.at_css("button[type=submit]")["data-turbo-confirm"]).to eq(I18n.t("iron_admin.resources.action.confirm"))
    end

    it "links Cancel to the index it came from" do
      expect(cancel_link[:href]).to eq(iron_admin.resources_path("flow_licenses", state))
    end

    it "opens the index from Cancel as a whole page, outside the form's frame" do
      expect(cancel_link["data-turbo-frame"]).to eq("_top")
    end

    context "with one selected record" do
      let(:licenses) { [license] }

      it "says it applies to one record" do
        expect(form.text.squish).to include(I18n.t("iron_admin.resources.bulk_action_form.selected", count: 1))
      end
    end

    context "when the form is submitted" do
      before do
        # One-row pages keep page 2 of the two licenses, so the redirect does not cap it.
        IronAdmin.configuration.per_page = 1
        post bulk_execute_path(:bulk_annotate),
             params: URI.encode_www_form(hidden_fields(form) + [["action_form[note]", "Checked"]]),
             headers: { "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
      end

      it "runs the action on the selected records" do
        expect(licenses.map { |selected| selected.reload.license_type }).to eq(%w[Checked Checked])
      end

      it "goes back to the index it came from" do
        expect(response).to redirect_to(iron_admin.resources_path("flow_licenses", state))
      end
    end
  end

  describe "GET /:resource_name/bulk_actions/:action_name/form with fields that have defaults" do
    before { get bulk_form_path(:bulk_review), params: { ids: [license.id] }, as: :html }

    it "fills a text field with its default" do
      expect(document.at_css("input#action_form_tag")[:value]).to eq("renewal")
    end

    it "checks a boolean whose default is true" do
      expect(document.at_css("input#action_form_notify_customer")[:checked]).to be_present
    end
  end

  describe "record lookup of GET /:resource_name/bulk_actions/:action_name/form" do
    let(:licenses) { create_list(:license, 2, status: :active) }

    context "without selected records" do
      before { get bulk_form_path(:bulk_annotate), as: :html }

      it "goes back to the index, as the bulk action does" do
        expect(response).to redirect_to(iron_admin.resources_path("flow_licenses"))
      end

      it "says that no record was selected" do
        expect(flash[:alert]).to eq(I18n.t("iron_admin.resources.bulk_action.no_records"))
      end
    end

    context "with a tampered id" do
      before { get bulk_form_path(:bulk_annotate), params: { ids: [licenses.first.id, 999_999] }, as: :html }

      it "goes back to the index, as the bulk action does" do
        expect(response).to redirect_to(iron_admin.resources_path("flow_licenses"))
      end

      it "says that some records are not accessible" do
        expect(flash[:alert]).to eq(I18n.t("iron_admin.resources.bulk_action.inaccessible"))
      end
    end

    context "with a record outside the tenant scope" do
      before do
        tenant = licenses.first.user
        IronAdmin.configure { |config| config.tenant_scope { |scope| scope.where(user_id: tenant.id) } }
        get bulk_form_path(:bulk_annotate), params: { ids: licenses.map(&:id) }, as: :html
      end

      it "says that some records are not accessible" do
        expect(flash[:alert]).to eq(I18n.t("iron_admin.resources.bulk_action.inaccessible"))
      end
    end

    context "with an unknown action" do
      it "returns not found" do
        get bulk_form_path(:missing), params: { ids: licenses.map(&:id) }, as: :html
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an action the policy denies" do
      before do
        flow_resource.class_eval do
          policy do
            allow :read
            deny :bulk_annotate
          end
        end
      end

      it "forbids its form" do
        get bulk_form_path(:bulk_annotate), params: { ids: licenses.map(&:id) }, as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /:resource_name/:id/actions/:action_name with a required field" do
    let(:events) { [] }
    let(:controls) { IronAdmin::Form::ControlClasses }
    let(:note) { document.at_css("#action_form_note") }

    before { IronAdmin.configure { |config| config.on_action { |event| events << event } } }

    context "when it is left blank in the form" do
      before { post execute_path(:annotate), params: { action_form: { note: "  ", tag: "kept" } }, as: :html }

      it "does not run the action" do
        expect(license.reload.license_type).to eq("standard")
      end

      it "does not report the action to on_action" do
        expect(events).to be_empty
      end

      it "renders the form again as unprocessable" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "still posts the form to the action" do
        expect(document.at_css("form[action='#{execute_path(:annotate)}']")).to be_present
      end

      it "says under the field that it can't be blank" do
        expect(document.at_css("#action_form_note_error").text.strip).to eq(I18n.t("errors.messages.blank"))
      end

      it "writes the error in the theme's error color" do
        expect(document.at_css("#action_form_note_error")[:class].split).to include(theme.error_text)
      end

      it "outlines the field as invalid, as resource forms do" do
        expect(note[:class].split).to eq(controls.textarea(theme, error: true).split)
      end

      it "tells screen readers the field is invalid and why" do
        expect(note.attributes.slice("aria-invalid", "aria-describedby").transform_values(&:value))
          .to eq("aria-invalid" => "true", "aria-describedby" => "action_form_note_error")
      end

      it "keeps what was typed in the other fields" do
        expect(document.at_css("#action_form_tag")[:value]).to eq("kept")
      end

      it "leaves a field without an error as it was" do
        expect(document.at_css("#action_form_tag")[:class].split).to eq(controls.input(theme).split)
      end

      it "still asks for confirmation on the submit" do
        expect(document.at_css("button[type=submit]")["data-turbo-confirm"]).to eq("Annotate this license?")
      end

      it "still opens the record from Cancel as a whole page" do
        expect(cancel_link["data-turbo-frame"]).to eq("_top")
      end

      it "names every control of the form" do
        expect(form_accessibility_problems(document)).to be_empty
      end
    end

    context "when a direct POST leaves it out" do
      before { post execute_path(:annotate), as: :html }

      it "does not run the action" do
        expect(license.reload.license_type).to eq("standard")
      end

      it "renders the form with the error" do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when it is filled and an optional field is left blank" do
      before { post execute_path(:annotate), params: { action_form: { note: "Checked", tag: "" } }, as: :html }

      it "runs the action" do
        expect(license.reload.license_type).to eq("Checked")
      end

      it "goes to the record" do
        expect(response).to redirect_to(iron_admin.resource_path("flow_licenses", license))
      end
    end

    # The form comes back with what was submitted in every kind of input, not with the defaults.
    context "when it is left blank and the other fields are filled" do
      before do
        post execute_path(:triage), params: {
          action_form: {
            priority: "", reason: "Typed reason", level: "two", notify: "1",
            count: "7", due_on: "2026-11-03", due_at: "2026-11-03T10:30",
          },
        }, as: :html
      end

      it "renders the form again as unprocessable" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "keeps the text of a textarea" do
        expect(document.at_css("#action_form_reason").text.strip).to eq("Typed reason")
      end

      it "keeps the option picked in a select" do
        expect(document.at_css("#action_form_level option[selected]")[:value]).to eq("two")
      end

      it "keeps a checked checkbox checked" do
        expect(document.at_css("#action_form_notify")[:checked]).to be_present
      end

      it "keeps an unchecked checkbox unchecked, even when its default is true" do
        expect(document.at_css("#action_form_escalate")[:checked]).to be_nil
      end

      it "keeps the number" do
        expect(document.at_css("#action_form_count")[:value]).to eq("7")
      end

      it "keeps the date" do
        expect(document.at_css("#action_form_due_on")[:value]).to eq("2026-11-03")
      end

      it "keeps the date and time" do
        expect(document.at_css("#action_form_due_at")[:value]).to start_with("2026-11-03T10:30")
      end
    end
  end

  describe "POST /:resource_name/:id/actions/:action_name with a required boolean" do
    let(:ran) { license.reload.license_type == "purged" }

    context "when its box is not checked" do
      before { post execute_path(:purge), params: { action_form: { i_understand: "0" } }, as: :html }

      it "does not run the action" do
        expect(ran).to be(false)
      end

      it "renders the form again as unprocessable" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "says under the checkbox that it can't be blank" do
        expect(document.at_css("#action_form_i_understand_error").text.strip).to eq(I18n.t("errors.messages.blank"))
      end
    end

    context "when a direct POST sends \"false\"" do
      before { post execute_path(:purge), params: { action_form: { i_understand: "false" } }, as: :html }

      it "does not run the action" do
        expect(ran).to be(false)
      end
    end

    context "when its box is checked" do
      before { post execute_path(:purge), params: { action_form: { i_understand: "1" } }, as: :html }

      it "runs the action" do
        expect(ran).to be(true)
      end
    end
  end

  describe "POST /:resource_name/bulk_actions/:action_name with a required field" do
    let(:licenses) { create_list(:license, 2, status: :active) }
    let(:state) { { "sort" => "license_key", "direction" => "desc" } }
    let(:form) { document.at_css("form[action='#{bulk_execute_path(:bulk_annotate)}']") }

    context "when it is left blank in the form" do
      before do
        post bulk_execute_path(:bulk_annotate),
             params: state.merge("ids" => licenses.map(&:id), "action_form" => { "note" => "" }), as: :html
      end

      it "does not run the action" do
        expect(licenses.map { |selected| selected.reload.license_type }).to eq(%w[standard standard])
      end

      it "renders the form again as unprocessable" do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "says under the field that it can't be blank" do
        expect(form.at_css("#action_form_note_error").text.strip).to eq(I18n.t("errors.messages.blank"))
      end

      it "keeps the selection and the index state" do
        expect(hidden_fields(form)).to contain_exactly(*licenses.map { |selected| ["ids[]", selected.id.to_s] }, *state.to_a)
      end

      it "still says how many records the action applies to" do
        expect(form.text.squish).to include(I18n.t("iron_admin.resources.bulk_action_form.selected", count: 2))
      end

      it "still opens the index from Cancel as a whole page" do
        expect(cancel_link["data-turbo-frame"]).to eq("_top")
      end
    end

    context "when it is left blank and the other fields are filled" do
      before do
        post bulk_execute_path(:bulk_review),
             params: { "ids" => licenses.map(&:id), "action_form" => { "note" => "", "tag" => "kept" } }, as: :html
      end

      it "keeps what was typed in the other fields" do
        expect(document.at_css("#action_form_tag")[:value]).to eq("kept")
      end

      it "keeps an unchecked checkbox unchecked, even when its default is true" do
        expect(document.at_css("#action_form_notify_customer")[:checked]).to be_nil
      end
    end

    context "when a direct POST leaves it out" do
      before { post bulk_execute_path(:bulk_annotate), params: { ids: licenses.map(&:id) }, as: :html }

      it "does not run the action" do
        expect(licenses.map { |selected| selected.reload.license_type }).to eq(%w[standard standard])
      end

      it "renders the form with the error" do
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when the selection is out of reach" do
      before do
        post bulk_execute_path(:bulk_annotate), params: { ids: [licenses.first.id, 999_999] }, as: :html
      end

      it "goes back to the index before checking the form" do
        expect(flash[:alert]).to eq(I18n.t("iron_admin.resources.bulk_action.inaccessible"))
      end
    end
  end

  describe "action forms in a dark theme picked by the theme cookie" do
    let(:night) do
      IronAdmin.configuration.register_theme(:night) do |night|
        night.color_scheme = "dark"
        night.card_bg = "bg-zinc-900"
        night.label_text = "text-zinc-200"
        night.muted_text = "text-zinc-400"
        night.input_border = "border-zinc-700"
        night.input_error = "border-red-400"
        night.error_text = "text-red-400"
      end
    end
    let(:controls) { IronAdmin::Form::ControlClasses }

    before do
      night
      cookies["iron_admin_theme"] = "night"
    end

    context "with a member form that came back with an error" do
      before { post execute_path(:annotate), params: { action_form: { note: "" } }, as: :html }

      it "outlines the field with that theme's error classes" do
        expect(document.at_css("#action_form_note")[:class].split).to eq(controls.textarea(night, error: true).split)
      end

      it "writes the error in that theme's error color" do
        expect(document.at_css("#action_form_note_error")[:class].split).to include("text-red-400")
      end

      it "writes the labels in that theme's label color" do
        expect(document.at_css("label[for=action_form_tag]")[:class].split).to include("text-zinc-200")
      end

      it "renders the other fields as that theme's inputs" do
        expect(document.at_css("#action_form_tag")[:class].split).to eq(controls.input(night).split)
      end
    end

    context "with a bulk form" do
      before { get bulk_form_path(:bulk_annotate), params: { ids: [license.id] }, as: :html }

      it "writes the record count in that theme's muted text color" do
        count = document.css("p").find { |line| line.text.include?(I18n.t("iron_admin.resources.bulk_action_form.selected", count: 1)) }
        expect(count[:class].split).to include("text-zinc-400")
      end

      it "renders the field as that theme's textarea" do
        expect(document.at_css("#action_form_note")[:class].split).to eq(controls.textarea(night).split)
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
