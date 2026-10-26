require "rails_helper"
require_relative "../../support/test_resources"

RSpec.describe "IronAdmin index filters", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    register_test_resources
  end

  describe "a declared filter on an enum column" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "DeclaredEnumFilterLicenseResource"
        end

        def self.resource_name
          "declared_enum_filter_licenses"
        end

        filter :status, type: :select
        index_fields :license_key, :status
      end
    end

    let(:user) { create(:user) }

    before do
      IronAdmin::ResourceRegistry.register(resource)
      create(:license, user: user, status: :active, license_key: "KEY-ACTIVE")
      create(:license, user: user, status: :expired, license_key: "KEY-EXPIRED")
    end

    it "renders a single select for the filter" do
      get iron_admin.resources_path("declared_enum_filter_licenses"), as: :html

      expect(response.parsed_body.css("select[name='filters[status]']").size).to eq(1)
    end

    it "offers the enum values in the select" do
      get iron_admin.resources_path("declared_enum_filter_licenses"), as: :html

      options = response.parsed_body.css("select[name='filters[status]'] option").pluck("value")
      expect(options).to eq(["", "active", "expired", "revoked"])
    end

    it "counts the active filter once" do
      get iron_admin.resources_path("declared_enum_filter_licenses"), params: { filters: { status: "expired" } }, as: :html

      expect(response.parsed_body.css("details summary span").map { |s| s.text.strip }).to include("1")
    end

    it "narrows the rows to the chosen value" do
      get iron_admin.resources_path("declared_enum_filter_licenses"), params: { filters: { status: "expired" } }, as: :html

      expect(response.body).to include("KEY-EXPIRED")
      expect(response.body).not_to include("KEY-ACTIVE")
    end
  end

  describe "a :password field" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = Document

        def self.name
          "PasswordFilterDocumentResource"
        end

        def self.resource_name
          "password_filter_documents"
        end

        field :password_hash, type: :password
        index_fields :id, :title
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(resource)
      create(:document, title: "Matching Doc", password_hash: "tok_abc123")
      create(:document, title: "Other Doc", password_hash: "zzz_999")
    end

    it "renders no filter control for it" do
      get iron_admin.resources_path("password_filter_documents"), as: :html

      expect(response.body).not_to include("filters[password_hash]")
    end

    it "ignores a crafted filter on it" do
      get iron_admin.resources_path("password_filter_documents"),
          params: { filters: { password_hash: { op: "starts_with", value: "tok_" } } },
          as: :html

      expect(response.body).to include("Matching Doc", "Other Doc")
    end
  end
end
