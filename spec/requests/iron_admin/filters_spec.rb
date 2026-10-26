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

  describe "a declared filter on an enum column with options of its own" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "DeclaredOptionsEnumFilterLicenseResource"
        end

        def self.resource_name
          "declared_options_enum_filter_licenses"
        end

        filter :status, type: :select, options: %w[active]
        index_fields :license_key, :status
      end
    end

    before { IronAdmin::ResourceRegistry.register(resource) }

    it "offers only the declared options" do
      get iron_admin.resources_path("declared_options_enum_filter_licenses"), as: :html

      expect(response.parsed_body.css("select[name='filters[status]'] option").pluck("value")).to eq(["", "active"])
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

    context "when the resource declares a filter on it" do
      before { resource.filter :password_hash, type: :string }

      it "applies the declared filter" do
        get iron_admin.resources_path("password_filter_documents"),
            params: { filters: { password_hash: { op: "equals", value: "tok_abc123" } } }, as: :html

        expect(response.body).not_to include("Other Doc")
      end
    end
  end

  # The filter form always submits the operator of string and number filters, even with no value.
  describe "the Filters badge" do
    subject(:filters_panel) do
      get iron_admin.resources_path("badge_filter_licenses"), params: { filters: filter_params }, as: :html
      response.parsed_body.at_css("details:has(input[name='filters[license_key][value]'])")
    end

    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "BadgeFilterLicenseResource"
        end

        def self.resource_name
          "badge_filter_licenses"
        end

        filter :license_key, type: :string
        filter :max_devices, type: :number
        filter :status, type: :select
        index_fields :license_key, :status
      end
    end

    let(:empty_operators) { { license_key: { op: "contains", value: "" }, max_devices: { op: "equals", value: "" } } }
    let(:badge_text) { filters_panel.css("summary span").map { |span| span.text.strip } }

    before { IronAdmin::ResourceRegistry.register(resource) }

    context "with a select filter and operator filters left empty" do
      let(:filter_params) { empty_operators.merge(status: "expired") }

      it "counts only the filter with a value" do
        expect(badge_text).to eq(%w[Filters 1])
      end
    end

    context "with an operator filter that has a value" do
      let(:filter_params) { empty_operators.merge(license_key: { op: "contains", value: "KEY" }) }

      it "counts it" do
        expect(badge_text).to eq(%w[Filters 1])
      end
    end

    context "with only empty operator filters" do
      let(:filter_params) { empty_operators }

      it "shows no count" do
        expect(badge_text).to eq(%w[Filters])
      end

      it "keeps the panel closed" do
        expect(filters_panel["open"]).to be_nil
      end
    end
  end

  # Filters follow field visibility, and a visible: false field is hidden from every user.
  describe "a declared filter on a visible: false field" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = Document

        def self.name
          "InvisibleFilterDocumentResource"
        end

        def self.resource_name
          "invisible_filter_documents"
        end

        field :password_hash, visible: false
        filter :password_hash, type: :string
        index_fields :id, :title
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(resource)
      create(:document, title: "Matching Doc", password_hash: "tok_abc123")
      create(:document, title: "Other Doc", password_hash: "zzz_999")
    end

    it "ignores the declared filter" do
      get iron_admin.resources_path("invisible_filter_documents"),
          params: { filters: { password_hash: { op: "equals", value: "tok_abc123" } } }, as: :html

      expect(response.body).to include("Matching Doc", "Other Doc")
    end
  end
end
