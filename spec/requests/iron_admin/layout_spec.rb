# frozen_string_literal: true

require "rails_helper"

# The dummy app overrides `layouts/iron_admin/application` with a bare ERB
# layout, so the other request specs never render the engine's real layout
# (its importmap tags, stylesheets and shell). This spec puts the engine's
# own views first so the real layout renders.
RSpec.describe "Engine layout", type: :request do
  around do |example|
    original_view_paths = IronAdmin::ApplicationController.view_paths
    IronAdmin::ApplicationController.prepend_view_path(IronAdmin::Engine.root.join("app/views"))
    example.run
  ensure
    IronAdmin::ApplicationController.view_paths = original_view_paths
  end

  describe "GET /:resource_name" do
    subject(:body) do
      get iron_admin.resources_path("users"), as: :html
      response.body
    end

    it "pins every IronAdmin Stimulus controller in the rendered import map" do
      pins = IronAdmin::Engine.root.glob("app/javascript/iron_admin/controllers/*_controller.js").map do |file|
        %("iron_admin/controllers/#{file.basename(".js")}")
      end

      expect(pins).to all(satisfy { |pin| body.include?(pin) })
    end

    it "imports the IronAdmin entry point" do
      expect(body).to include(%(import "iron_admin"))
    end

    it "renders the shell sidebar" do
      expect(body).to match(/id=["']cp-sidebar-panel["']/)
    end

    it "renders the page content in the main landmark" do
      expect(Nokogiri::HTML(body).at_css("main#main-content h1")).to be_present
    end

    it "declares the page language" do
      expect(Nokogiri::HTML(body).at_css("html")["lang"]).to eq(I18n.locale.to_s)
    end
  end

  # The sidebar brand is not a heading, so each page needs its own h1.
  describe "action form pages" do
    subject(:document) do
      get path, as: :html
      response.parsed_body
    end

    let(:form_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name = "FormTitleResource"
        def self.resource_name = "form_title_licenses"

        action :revoke_with_reason, form_fields: [action_field(:reason, type: :textarea)] do |license, _params|
          license.update!(status: :revoked)
        end

        bulk_action :bulk_revoke_with_note, form_fields: [action_field(:note, type: :textarea)] do |licenses, _params|
          licenses.update_all(status: :revoked)
        end
      end
    end

    let(:form_tool) do
      Class.new(IronAdmin::Tool) do
        def self.name = "FormTitleTool"

        menu label: "Form Title"

        tool_action :with_form, label: "Action With Form", form_fields: [{ name: :reason, type: :textarea }]

        def with_form(ctx)
          # noop
        end
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(form_resource)
      IronAdmin::ToolRegistry.register(form_tool)
    end

    shared_examples "a page titled by its only h1" do |title|
      it "titles the page with its only h1" do
        expect(document.css("h1").map { |heading| heading.text.strip }).to eq([title])
      end

      it "puts the title in the main landmark" do
        expect(document.at_css("main#main-content h1")).to be_present
      end
    end

    describe "GET /tools/:tool_name/:action_name/form" do
      let(:path) { iron_admin.tool_action_form_path("form_title", "with_form") }

      it_behaves_like "a page titled by its only h1", "Action With Form"
    end

    describe "GET /:resource_name/:id/actions/:action_name/form" do
      let(:path) { iron_admin.resource_action_form_path("form_title_licenses", create(:license), "revoke_with_reason") }

      it_behaves_like "a page titled by its only h1", "Revoke with reason"
    end

    describe "GET /:resource_name/bulk_actions/:action_name/form" do
      let(:path) { iron_admin.resource_bulk_action_form_path("form_title_licenses", "bulk_revoke_with_note") }

      it_behaves_like "a page titled by its only h1", "Bulk revoke with note"
    end
  end

  describe "GET /search" do
    subject(:search_input) do
      get iron_admin.search_path(q: "Rails"), as: :html
      response.parsed_body.at_css("header input[name='q']")
    end

    it "keeps the query in the navbar search box" do
      expect(search_input[:value]).to eq("Rails")
    end
  end
end
