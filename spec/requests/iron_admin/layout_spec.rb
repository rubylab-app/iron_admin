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

  describe "theme" do
    subject(:document) do
      get iron_admin.resources_path("users"), as: :html
      response.parsed_body
    end

    let(:font_url) { "https://fonts.googleapis.com/css2?family=Inter:wght@400..700&display=swap" }
    let(:body_classes) { document.at_css("body")[:class].split }

    context "with the default theme" do
      it "sets the light color scheme class on the html element" do
        expect(document.at_css("html")[:class].split).to include("scheme-light")
      end

      it "declares the light color scheme" do
        expect(document.at_css("meta[name='color-scheme']")[:content]).to eq("light")
      end

      it "links the theme's font stylesheet" do
        expect(document.css("head link[rel='stylesheet']").pluck(:href)).to include(font_url)
      end

      it "preconnects to the Google Fonts hosts" do
        expect(document.css("head link[rel='preconnect']").pluck(:href))
          .to eq(["https://fonts.googleapis.com", "https://fonts.gstatic.com"])
      end

      it "allows the font files host to serve fonts across origins" do
        expect(document.at_css("head link[href='https://fonts.gstatic.com']").key?("crossorigin")).to be(true)
      end

      it "styles the body with the theme's background, text color and font" do
        expect(body_classes).to include("antialiased", "bg-zinc-50", "text-zinc-900",
                                        "font-[family-name:Inter,ui-sans-serif,system-ui,sans-serif]")
      end
    end

    context "with a dark theme picked by the theme cookie" do
      before do
        IronAdmin.configuration.register_theme(:midnight) do |t|
          t.color_scheme = "dark"
          t.main_bg = "bg-zinc-950"
          t.body_text = "text-zinc-100"
        end
        cookies["iron_admin_theme"] = "midnight"
      end

      it "sets the dark color scheme class on the html element" do
        expect(document.at_css("html")[:class].split).to include("scheme-dark")
      end

      it "declares the dark color scheme" do
        expect(document.at_css("meta[name='color-scheme']")[:content]).to eq("dark")
      end

      it "styles the body with that theme" do
        expect(body_classes).to include("bg-zinc-950", "text-zinc-100")
      end

      it "does not keep the default theme's body colors" do
        expect(body_classes).not_to include("bg-zinc-50", "text-zinc-900")
      end
    end

    context "with a font stylesheet off Google Fonts" do
      before { IronAdmin.configuration.theme.font_stylesheet_url = "https://cdn.example.com/fonts.css" }

      it "links it" do
        expect(document.css("head link[rel='stylesheet']").pluck(:href)).to include("https://cdn.example.com/fonts.css")
      end

      it "preconnects to no font host" do
        expect(document.css("head link[rel='preconnect']")).to be_empty
      end
    end

    context "without a font stylesheet" do
      before { IronAdmin.configuration.theme.font_stylesheet_url = nil }

      it "links no font stylesheet" do
        expect(document.css("head link[rel='preconnect'], head link[href*='fonts']")).to be_empty
      end
    end
  end

  describe "favicon" do
    subject(:icon_links) do
      get iron_admin.resources_path("users"), as: :html
      response.parsed_body.css("head link[rel~='icon']")
    end

    context "without config.favicon" do
      it "links no icon, as before" do
        expect(icon_links).to be_empty
      end
    end

    context "with config.favicon set to a path" do
      before { IronAdmin.configuration.favicon = "/brand/icon.svg" }

      it "links that icon" do
        expect(icon_links.pluck(:href)).to eq(["/brand/icon.svg"])
      end

      it "does not claim an image/x-icon type for it" do
        expect(icon_links.first[:type]).to be_nil
      end
    end

    context "with config.favicon set to a URL" do
      before { IronAdmin.configuration.favicon = "https://cdn.example.com/favicon.ico" }

      it "links that URL" do
        expect(icon_links.pluck(:href)).to eq(["https://cdn.example.com/favicon.ico"])
      end
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

  describe "sidebar link for the current page" do
    subject(:current_links) { response.parsed_body.css("#cp-sidebar-panel a[aria-current='page']").pluck(:href) }

    before { IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource) }

    context "with GET /" do
      before { get iron_admin.root_path, as: :html }

      it "is the dashboard link" do
        expect(current_links).to eq([iron_admin.root_path])
      end
    end

    context "with GET /:resource_name/:id/edit" do
      before { get iron_admin.edit_resource_path("users", create(:user)), as: :html }

      it "is the resource's link" do
        expect(current_links).to eq([iron_admin.resources_path("users")])
      end
    end

    context "with a create that fails validation and renders the form again" do
      before { post iron_admin.resources_path("users"), params: { record: { name: "", email: "" } }, as: :html }

      it "is still the resource's link" do
        expect(current_links).to eq([iron_admin.resources_path("users")])
      end
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
