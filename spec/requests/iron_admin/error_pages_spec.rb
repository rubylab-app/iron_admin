# frozen_string_literal: true

require "rails_helper"

# A bare 403/404 has no body, so a browser navigating to it shows its own
# error page. HTML requests get a page with a link back; other formats keep
# the bare status.
RSpec.describe "Error pages", type: :request do
  let(:page) { Nokogiri::HTML(response.body) }
  let(:heading) { page.at_css("#cp-error-page h1")&.text&.squish }
  let(:back_link) { page.at_css("#cp-error-page a")&.[]("href") }

  let(:read_only_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name = "ErrorPageReadOnlyResource"
      def self.resource_name = "read_only_users"

      policy { allow :read }
    end
  end

  let(:read_denied_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name = "ErrorPageReadDeniedResource"
      def self.resource_name = "read_denied_users"

      policy { deny :read }
    end
  end

  let(:user) { create(:user) }

  before do
    IronAdmin::ResourceRegistry.register(read_only_resource)
    IronAdmin::ResourceRegistry.register(read_denied_resource)
  end

  describe "an HTML request the policy forbids" do
    before { get iron_admin.edit_resource_path("read_only_users", user), as: :html }

    it "keeps the forbidden status" do
      expect(response).to have_http_status(:forbidden)
    end

    it "explains that the user is not authorized" do
      expect(heading).to eq("Not authorized")
    end

    it "links back to the resource index the user can read" do
      expect(back_link).to eq(iron_admin.resources_path("read_only_users"))
    end
  end

  describe "an HTML request for a resource the user cannot read" do
    before { get iron_admin.resources_path("read_denied_users"), as: :html }

    it "keeps the forbidden status" do
      expect(response).to have_http_status(:forbidden)
    end

    it "links back to the dashboard" do
      expect(back_link).to eq(iron_admin.root_path)
    end
  end

  describe "an HTML request for a missing record" do
    before { get iron_admin.resource_path("users", 999_999), as: :html }

    it "keeps the not found status" do
      expect(response).to have_http_status(:not_found)
    end

    it "explains that the page was not found" do
      expect(heading).to eq("Page not found")
    end

    it "links back to the resource index" do
      expect(back_link).to eq(iron_admin.resources_path("users"))
    end
  end

  describe "an HTML request for an unknown resource" do
    before { get iron_admin.resources_path("no_such_resources"), as: :html }

    it "keeps the not found status" do
      expect(response).to have_http_status(:not_found)
    end

    it "links back to the dashboard" do
      expect(back_link).to eq(iron_admin.root_path)
    end
  end

  describe "an HTML request for an unknown member action" do
    before { post iron_admin.resource_action_path("users", user, "no_such_action"), as: :html }

    it "keeps the not found status" do
      expect(response).to have_http_status(:not_found)
    end

    it "renders the not found page" do
      expect(heading).to eq("Page not found")
    end
  end

  describe "a Turbo form submission the policy forbids" do
    before do
      patch iron_admin.resource_path("read_only_users", user),
            params: { record: { name: "Blocked" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }
    end

    it "keeps the forbidden status" do
      expect(response).to have_http_status(:forbidden)
    end

    it "renders the page Turbo shows for a failed submission" do
      expect(heading).to eq("Not authorized")
    end
  end

  describe "an HTML request for an unknown tool" do
    before { get iron_admin.tool_path("no_such_tool"), as: :html }

    it "keeps the not found status" do
      expect(response).to have_http_status(:not_found)
    end

    it "renders the not found page" do
      expect(heading).to eq("Page not found")
    end
  end

  describe "an HTML request for the import page of a resource without imports" do
    before { get iron_admin.resource_import_path("users"), as: :html }

    it "keeps the not found status" do
      expect(response).to have_http_status(:not_found)
    end

    it "renders the not found page" do
      expect(heading).to eq("Page not found")
    end
  end

  describe "an HTML request for an export" do
    before { get iron_admin.export_path("users"), as: :html }

    it "keeps the not found status" do
      expect(response).to have_http_status(:not_found)
    end

    it "renders the not found page" do
      expect(heading).to eq("Page not found")
    end
  end

  describe "a JSON request the policy forbids" do
    before { get iron_admin.edit_resource_path("read_only_users", user), as: :json }

    it "keeps the forbidden status" do
      expect(response).to have_http_status(:forbidden)
    end

    it "keeps the empty body" do
      expect(response.body).to be_empty
    end
  end

  describe "a JSON request for a missing record" do
    before { get iron_admin.resource_path("users", 999_999), as: :json }

    it "keeps the not found status" do
      expect(response).to have_http_status(:not_found)
    end

    it "keeps the empty body" do
      expect(response.body).to be_empty
    end
  end

  describe "a Turbo Stream request for a missing record" do
    before do
      get iron_admin.resource_path("users", 999_999), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    it "keeps the not found status" do
      expect(response).to have_http_status(:not_found)
    end

    it "keeps the empty body" do
      expect(response.body).to be_empty
    end
  end

  describe "a CSV export the policy forbids" do
    before { get iron_admin.export_path("read_denied_users", format: :csv) }

    it "keeps the forbidden status" do
      expect(response).to have_http_status(:forbidden)
    end

    it "keeps the empty body" do
      expect(response.body).to be_empty
    end
  end

  describe "the page inside the engine layout" do
    # The dummy app overrides the engine layout (see layout_spec.rb).
    around do |example|
      original_view_paths = IronAdmin::ApplicationController.view_paths
      IronAdmin::ApplicationController.prepend_view_path(IronAdmin::Engine.root.join("app/views"))
      example.run
    ensure
      IronAdmin::ApplicationController.view_paths = original_view_paths
    end

    before { get iron_admin.edit_resource_path("read_only_users", user), as: :html }

    it "renders within the admin shell" do
      expect(page.at_css("#cp-sidebar-panel")).to be_present
    end

    it "renders the message in the shell's content area" do
      expect(page.at_css(".overflow-auto #cp-error-page")).to be_present
    end
  end
end
