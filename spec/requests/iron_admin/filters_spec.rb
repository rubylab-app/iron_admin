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

  describe "a select filter on a belongs_to foreign key" do
    subject(:options) { response.parsed_body.css("select[name='filters[user_id]'] option") }

    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "ForeignKeyFilterLicenseResource"
        end

        def self.resource_name
          "foreign_key_filter_licenses"
        end

        filter :user_id, type: :select
        index_fields :license_key
      end
    end
    let(:ada) { create(:user, name: "Ada") }
    let(:grace) { create(:user, name: "Grace") }

    before do
      IronAdmin::ResourceRegistry.register(resource)
      create(:license, user: ada)
      create(:license, user: grace)
    end

    it "labels each option with the associated record instead of its id" do
      get iron_admin.resources_path("foreign_key_filter_licenses"), as: :html

      expect(options.map { |option| [option.text.strip, option["value"]] })
        .to eq([["All", ""], ["Ada", ada.id.to_s], ["Grace", grace.id.to_s]])
    end

    it "selects the chosen record" do
      get iron_admin.resources_path("foreign_key_filter_licenses"), params: { filters: { user_id: grace.id } }, as: :html

      expect(options.select { |option| option["selected"] }.map { |option| option.text.strip }).to eq(["Grace"])
    end
  end

  describe "a select filter on the foreign key of a hidden belongs_to field" do
    subject(:option_labels) do
      response.parsed_body.css("select[name='filters[user_id]'] option").map { |option| option.text.strip }
    end

    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "HiddenOwnerFilterLicenseResource"
        end

        def self.resource_name
          "hidden_owner_filter_licenses"
        end

        field :user, visible: ->(user) { user&.role == "admin" }
        filter :user_id, type: :select
        index_fields :license_key
      end
    end
    let(:ada) { create(:user, name: "Ada") }

    before do
      IronAdmin::ResourceRegistry.register(resource)
      create(:license, user: ada)
      create(:user, name: "Secret Person")
      role = viewer_role
      IronAdmin.configure { |config| config.current_user { Struct.new(:role).new(role) } }
      get iron_admin.resources_path("hidden_owner_filter_licenses"), as: :html
    end

    context "when the viewer cannot see the field" do
      let(:viewer_role) { "member" }

      it "offers the column's values instead of the associated records' labels" do
        expect(option_labels).to eq(["All", ada.id.to_s])
      end
    end

    context "when the viewer can see the field" do
      let(:viewer_role) { "admin" }

      it "labels the associated records" do
        expect(option_labels).to eq(["All", "Ada", "Secret Person"])
      end
    end
  end

  describe "a select filter on the foreign key of an autocomplete belongs_to field" do
    subject(:options) { response.parsed_body.css("select[name='filters[user_id]'] option") }

    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "AutocompleteOwnerFilterLicenseResource"
        end

        def self.resource_name
          "autocomplete_owner_filter_licenses"
        end

        belongs_to :user, autocomplete: true
        filter :user_id, type: :select
        index_fields :license_key
      end
    end
    let(:ada) { create(:user, name: "Ada") }

    before do
      IronAdmin::ResourceRegistry.register(resource)
      create(:license, user: ada)
      create(:user, name: "Unreferenced")
      get iron_admin.resources_path("autocomplete_owner_filter_licenses"), as: :html
    end

    it "offers the ids the column holds instead of every associated record" do
      expect(options.map { |option| [option.text.strip, option["value"]] })
        .to eq([["All", ""], [ada.id.to_s, ada.id.to_s]])
    end
  end

  describe "a select filter on a foreign key that stores another key of the associated record" do
    subject(:options) { response.parsed_body.css("select[name='filters[license_type]'] option") }

    let(:license_model) do
      Class.new(License) do
        def self.name
          "OwnerEmailLicense"
        end

        belongs_to :owner, class_name: "User", foreign_key: :license_type, primary_key: :email, optional: true
      end
    end
    let(:resource) do
      model_class = license_model

      Class.new(IronAdmin::Resource) do
        self.model_class_override = model_class

        def self.name
          "OwnerEmailFilterLicenseResource"
        end

        def self.resource_name
          "owner_email_filter_licenses"
        end

        filter :license_type, type: :select
        index_fields :license_key
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(resource)
      ada = create(:user, name: "Ada", email: "ada@example.com")
      bob = create(:user, name: "Bob", email: "bob@example.com")
      create(:license, user: ada, license_key: "ADA-KEY", license_type: ada.email)
      create(:license, user: bob, license_key: "BOB-KEY", license_type: bob.email)
    end

    it "gives each option the key the foreign key stores" do
      get iron_admin.resources_path("owner_email_filter_licenses"), as: :html

      expect(options.map { |option| [option.text.strip, option["value"]] })
        .to eq([["All", ""], ["Ada", "ada@example.com"], ["Bob", "bob@example.com"]])
    end

    it "narrows the rows to the chosen record" do
      get iron_admin.resources_path("owner_email_filter_licenses"),
          params: { filters: { license_type: "ada@example.com" } }, as: :html

      expect(%w[ADA-KEY BOB-KEY].select { |key| response.body.include?(key) }).to eq(["ADA-KEY"])
    end
  end

  describe "a select filter with callable options" do
    subject(:options) { response.parsed_body.css("select[name='filters[license_type]'] option") }

    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "CallableOptionsFilterLicenseResource"
        end

        def self.resource_name
          "callable_options_filter_licenses"
        end

        filter :license_type, type: :select, options: -> { License.distinct.order(:license_type).pluck(:license_type) }
        index_fields :license_key
      end
    end

    # The license is created after the resource is defined, so only a render-time evaluation offers its type.
    before do
      IronAdmin::ResourceRegistry.register(resource)
      create(:license, license_type: "enterprise")
    end

    it "offers what the callable returns when the page renders" do
      get iron_admin.resources_path("callable_options_filter_licenses"), as: :html

      expect(options.map { |option| [option.text.strip, option["value"]] }).to eq([["All", ""], %w[Enterprise enterprise]])
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
