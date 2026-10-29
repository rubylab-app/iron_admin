require "rails_helper"
require_relative "../../support/test_resources"

RSpec.describe "IronAdmin::Search", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  describe "GET /search" do
    it "returns matching results" do
      create(:user, name: "John Doe", email: "john@example.com")
      create(:user, name: "Jane Smith", email: "jane@example.com")

      get iron_admin.search_path(q: "John")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("John Doe")
      expect(response.body).not_to include("Jane Smith")
    end

    context "with a query" do
      let(:document) do
        get iron_admin.search_path(q: "John")
        response.parsed_body
      end

      before { create(:user, name: "John Doe", email: "john@example.com") }

      it "shows the query in the heading" do
        expect(document.at_css("h1").text.squish).to eq("Search results for John")
      end

      # <q> draws the language's quotation marks, curly ones in English.
      it "quotes the query with a q element" do
        expect(document.at_css("h1 q").text).to eq("John")
      end

      # A theme may set page titles in capitals; the query stays as it was typed.
      it "keeps the query's case whatever the theme does to the title" do
        expect(document.at_css("h1 q")[:class].split).to include("normal-case")
      end

      # A result is a link to the record, like the related records of a show page.
      it "colors each result's label with the theme's link color" do
        label = document.at_css("a[href='#{iron_admin.resource_path("users", User.find_by(name: "John Doe"))}'] span")
        expect(label[:class].split).to include(*IronAdmin.current_theme.link.split)
      end
    end

    context "without a query" do
      it "shows the plain heading" do
        get iron_admin.search_path

        expect(response.parsed_body.at_css("h1").text.strip).to eq("Search results")
      end
    end

    it "returns empty when no query" do
      get iron_admin.search_path
      expect(response).to have_http_status(:ok)
    end

    context "with a record that has a title but no name or email" do
      subject(:result_label) do
        get iron_admin.search_path(q: "Quarterly")
        response.parsed_body.at_css("a[href='#{iron_admin.resource_path("posts", report)}']").text.strip
      end

      let!(:report) { create(:post, title: "Quarterly report") }

      before { IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource) }

      it "labels the result with its title" do
        expect(result_label).to eq("Quarterly report")
      end
    end

    context "with a record that has no display attribute" do
      subject(:result_label) do
        get iron_admin.search_path(q: "KEY-LABEL")
        response.parsed_body.at_css("a[href='#{iron_admin.resource_path("licenses", license)}']").text.strip
      end

      let!(:license) { create(:license, license_key: "KEY-LABEL-1") }

      before { IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource) }

      it "labels the result with the model name and id" do
        expect(result_label).to eq("License ##{license.id}")
      end
    end

    it "applies tenant scope to global search results" do
      create(:user, name: "In Tenant", email: "visible@example.com", active: true)
      create(:user, name: "Out Of Tenant", email: "hidden@example.com", active: false)

      IronAdmin.configure do |config|
        config.tenant_scope do |scope|
          scope.where(active: true)
        end
      end

      get iron_admin.search_path(q: "example.com")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("In Tenant")
      expect(response.body).not_to include("Out Of Tenant")
    end

    it "applies tenant scope independently across searched resources" do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)

      visible_user = create(:user, name: "Tenant Shared", email: "shared-visible@example.com", active: true)
      hidden_user = create(:user, name: "Tenant Shared Hidden", email: "shared-hidden@example.com", active: false)
      visible_license = create(:license, user: visible_user, license_key: "TENANT-SHARED-VISIBLE")
      hidden_license = create(:license, user: hidden_user, license_key: "TENANT-SHARED-HIDDEN")

      IronAdmin.configure do |config|
        config.tenant_scope do |scope|
          if scope.klass == User
            scope.where(active: true)
          else
            scope.joins(:user).where(users: { active: true })
          end
        end
      end

      get iron_admin.search_path(q: "Shared")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Tenant Shared")
      expect(response.body).to include(iron_admin.resource_path("licenses", visible_license))
      expect(response.body).not_to include("Tenant Shared Hidden")
      expect(response.body).not_to include(iron_admin.resource_path("licenses", hidden_license))
    end
  end
end
