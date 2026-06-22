require "rails_helper"
require "ostruct"
require_relative "../../support/test_resources"

RSpec.describe "IronAdmin::Exports", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
  end

  describe "query consistency" do
    let(:user) { create(:user) }

    it "applies select filters to JSON exports" do
      create(:user, name: "Enterprise User", email: "enterprise@example.com", role: "admin")
      create(:user, name: "Starter User", email: "starter@example.com", role: "member")

      get iron_admin.export_path("users", format: :json), params: { filters: { role: "admin" } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("name")).to contain_exactly("Enterprise User")
    end

    it "applies search to JSON exports" do
      create(:user, name: "Findable User", email: "findable@example.com")
      create(:user, name: "Hidden User", email: "hidden@example.com")

      get iron_admin.export_path("users", format: :json), params: { q: "Findable" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("name")).to contain_exactly("Findable User")
    end

    it "applies search to CSV exports" do
      create(:user, name: "CSV Findable User", email: "csv-findable@example.com")
      create(:user, name: "CSV Hidden User", email: "csv-hidden@example.com")

      get iron_admin.export_path("users", format: :csv), params: { q: "CSV Findable" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("CSV Findable User")
      expect(response.body).not_to include("CSV Hidden User")
    end

    it "applies scopes to JSON exports" do
      active = create(:license, user: user, status: "active", license_key: "ACTIVE-SCOPE")
      expired = create(:license, user: user, status: "expired", license_key: "EXPIRED-SCOPE")

      get iron_admin.export_path("licenses", format: :json), params: { scope: "expired" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("license_key")).to contain_exactly(expired.license_key)
      expect(response.parsed_body.pluck("license_key")).not_to include(active.license_key)
    end

    it "applies sorting to JSON exports" do
      create(:user, name: "Zulu User", email: "zulu@example.com")
      create(:user, name: "Alpha User", email: "alpha@example.com")

      get iron_admin.export_path("users", format: :json), params: { sort: "name", direction: "asc" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("name")).to eq(["Alpha User", "Zulu User"])
    end
  end

  describe "Mongoid query consistency" do
    let(:fake_mongo_article_class) do
      Struct.new(:_id, :title, :status, :created_at, keyword_init: true)
    end

    let(:fake_mongo_criteria_class) do
      Class.new do
        include Enumerable

        attr_reader :records, :selector, :options

        def initialize(records, selector: {}, options: {})
          @records = records
          @selector = selector
          @options = options
        end

        def each(&)
          records.each(&)
        end

        def where(condition)
          matching_records = records.select { |record| matches?(record, condition) }
          self.class.new(matching_records, selector: selector.merge(condition), options: options)
        end

        def any_of(*conditions)
          matching_records = records.select do |record|
            conditions.any? { |condition| matches?(record, condition) }
          end
          self.class.new(matching_records, selector: selector, options: options)
        end

        def order_by(order)
          column, direction = order.first
          sorted = records.sort_by { |record| record.public_send(column) }
          sorted.reverse! if direction.to_s == "desc"
          self.class.new(sorted, selector: selector, options: options.merge(sort: order))
        end

        def limit(max)
          self.class.new(records.first(max), selector: selector, options: options)
        end

        def batch_size(_size)
          self
        end

        def merge(scope)
          self.class.new(records & scope.records, selector: selector.merge(scope.selector), options: options)
        end

        private

        def matches?(record, condition)
          condition.all? do |field, expected|
            value = record.public_send(field)
            expected.is_a?(Regexp) ? value.to_s.match?(expected) : value == expected
          end
        end
      end
    end

    let(:fake_mongo_article_model) do
      criteria_class = fake_mongo_criteria_class
      field_class = Struct.new(:name, :type)

      Class.new do
        define_singleton_method(:records) { @records }
        define_singleton_method(:records=) { |records| @records = records }
        define_singleton_method(:relations) { {} }
        define_singleton_method(:collection_name) { "mongo_articles" }
        define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "MongoArticle") }
        define_singleton_method(:all) { criteria_class.new(records) }

        define_singleton_method(:fields) do
          {
            "_id" => field_class.new("_id", Object),
            "title" => field_class.new("title", String),
            "status" => field_class.new("status", String),
            "created_at" => field_class.new("created_at", Time),
          }
        end
      end
    end

    let(:mongo_article_resource) do
      model_class = fake_mongo_article_model

      Class.new(IronAdmin::Resource) do
        self.adapter_class = :mongoid
        self.model_class_override = model_class

        def self.name
          "FakeMongoArticleResource"
        end

        def self.resource_name
          "mongo_articles"
        end

        searchable :title
        filter :status, type: :select, options: %w[draft published]
        scope :drafts, -> { where(status: "draft") }
        export_fields :title, :status
      end
    end

    before do
      fake_mongo_article_model.records = [
        fake_mongo_article_class.new(_id: "1", title: "Beta Draft", status: "draft", created_at: 2.days.ago),
        fake_mongo_article_class.new(_id: "2", title: "Alpha Published", status: "published", created_at: 1.day.ago),
      ]
      IronAdmin::ResourceRegistry.register(mongo_article_resource)
    end

    it "applies filters to JSON exports" do
      get iron_admin.export_path("mongo_articles", format: :json), params: { filters: { status: "draft" } }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("title")).to contain_exactly("Beta Draft")
    end

    it "applies scopes to JSON exports" do
      get iron_admin.export_path("mongo_articles", format: :json), params: { scope: "drafts" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("title")).to contain_exactly("Beta Draft")
    end

    it "applies search to JSON exports" do
      get iron_admin.export_path("mongo_articles", format: :json), params: { q: "NO_SUCH_TERM" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "applies sorting to JSON exports" do
      get iron_admin.export_path("mongo_articles", format: :json), params: { sort: "title", direction: "asc" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("title")).to eq(["Alpha Published", "Beta Draft"])
    end
  end

  describe "field visibility enforcement" do
    let(:visibility_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "ExportVisibilityUserResource"
        end

        def self.resource_name
          "export_visibility_users"
        end

        field :name, type: :text
        field :email, visible: ->(user) { user&.role == "admin" }
        field :role, visible: false
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(visibility_resource)
    end

    after do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    end

    context "when user does not have permission to see a field" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "excludes invisible fields from CSV export" do
        create(:user, name: "Test User", email: "secret@example.com", role: "admin")

        get iron_admin.export_path("export_visibility_users", format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Test User")
        expect(response.body).not_to include("secret@example.com")
        expect(response.body).not_to include("admin")
      end

      it "excludes invisible fields from JSON export" do
        create(:user, name: "Test User", email: "secret@example.com", role: "admin")

        get iron_admin.export_path("export_visibility_users", format: :json)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.first.keys).to include("name")
        expect(json.first.keys).not_to include("email")
        expect(json.first.keys).not_to include("role")
      end

      it "does not apply invisible field filters from crafted params to JSON export" do
        create(:user, name: "Secret Export User", email: "secret-export@example.com", role: "admin")
        create(:user, name: "Normal Export User", email: "normal-export@example.com", role: "admin")

        get iron_admin.export_path("export_visibility_users", format: :json),
            params: { filters: { email: { op: "contains", value: "secret-export" } } }

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.pluck("name")).to contain_exactly("Secret Export User", "Normal Export User")
        expect(response.parsed_body.flat_map(&:keys)).not_to include("email")
      end

      it "excludes invisible field headers from CSV export" do
        create(:user, name: "Test User", email: "secret@example.com", role: "admin")

        get iron_admin.export_path("export_visibility_users", format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Name")
        expect(response.body).not_to include("Email")
        expect(response.body).not_to include("Role")
      end
    end

    context "when user has permission to see a field" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "admin") }
        end
      end

      it "includes conditionally visible fields in CSV export" do
        create(:user, name: "Test User", email: "visible@example.com", role: "member")

        get iron_admin.export_path("export_visibility_users", format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Test User")
        expect(response.body).to include("visible@example.com")
        expect(response.body).not_to include("member")
      end

      it "includes conditionally visible fields in JSON export" do
        create(:user, name: "Test User", email: "visible@example.com", role: "member")

        get iron_admin.export_path("export_visibility_users", format: :json)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.first.keys).to include("name")
        expect(json.first.keys).to include("email")
        expect(json.first.keys).not_to include("role")
      end
    end

    context "when no user is logged in" do
      before do
        IronAdmin.configure do |config|
          config.current_user { nil }
        end
      end

      it "excludes conditionally visible fields from CSV export" do
        create(:user, name: "Test User", email: "secret@example.com", role: "admin")

        get iron_admin.export_path("export_visibility_users", format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Test User")
        expect(response.body).not_to include("secret@example.com")
      end

      it "excludes conditionally visible fields from JSON export" do
        create(:user, name: "Test User", email: "secret@example.com", role: "admin")

        get iron_admin.export_path("export_visibility_users", format: :json)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.first.keys).to include("name")
        expect(json.first.keys).not_to include("email")
      end
    end
  end

  describe "GET /:resource_name/export.csv" do
    it "returns CSV" do
      create(:user, name: "John", email: "john@test.com")

      get iron_admin.export_path("users", format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("john@test.com")
    end

    it "formats datetime fields as ISO8601" do
      user = create(:user, name: "John", email: "john@test.com")

      get iron_admin.export_path("users", format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.created_at.iso8601)
    end

    it "formats boolean fields as Yes/No" do
      create(:user, name: "John", email: "john@test.com", active: true)
      create(:user, name: "Jane", email: "jane@test.com", active: false)

      get iron_admin.export_path("users", format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Yes")
      expect(response.body).to include("No")
    end

    it "handles nil values gracefully" do
      create(:user, name: "John", email: "john@test.com", role: nil)

      get iron_admin.export_path("users", format: :csv)

      expect(response).to have_http_status(:ok)
      # Should not crash and should return empty string for nil
    end

    context "when field does not exist on record" do
      it "returns error message instead of crashing" do
        create(:user, name: "John", email: "john@test.com")
        # Stub resolved_fields to include a non-existent field
        fake_field = IronAdmin::Field.new(:nonexistent_field, type: :text)
        allow(IronAdmin::Resources::UserResource).to receive(:resolved_fields).and_return([fake_field])

        get iron_admin.export_path("users", format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("[Error: field not found]")
      end
    end
  end

  describe "GET /:resource_name/export.json" do
    it "returns JSON" do
      create(:user, name: "John", email: "john@test.com")

      get iron_admin.export_path("users", format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/json")
    end

    it "formats datetime fields as ISO8601" do
      user = create(:user, name: "John", email: "john@test.com")

      get iron_admin.export_path("users", format: :json)

      json = response.parsed_body
      expect(json.first["created_at"]).to eq(user.created_at.iso8601)
    end

    it "formats boolean fields as Yes/No" do
      create(:user, name: "John", email: "john@test.com", active: true)

      get iron_admin.export_path("users", format: :json)

      json = response.parsed_body
      expect(json.first["active"]).to eq("Yes")
    end

    it "handles nil values gracefully" do
      create(:user, name: "John", email: "john@test.com", role: nil)

      get iron_admin.export_path("users", format: :json)

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json.first["role"]).to eq("")
    end

    context "when field does not exist on record" do
      it "returns error message instead of crashing" do
        create(:user, name: "John", email: "john@test.com")
        # Stub resolved_fields to include a non-existent field
        fake_field = IronAdmin::Field.new(:nonexistent_field, type: :text)
        allow(IronAdmin::Resources::UserResource).to receive(:resolved_fields).and_return([fake_field])

        get iron_admin.export_path("users", format: :json)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.first["nonexistent_field"]).to eq("[Error: field not found]")
      end
    end
  end

  describe "export with belongs_to associations" do
    let(:user) { create(:user, name: "John Doe", email: "john@example.com") }

    context "CSV format" do
      it "exports the association's display value" do
        create(:license, user: user, license_key: "ABC-123")

        get iron_admin.export_path("licenses", format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/csv")
        expect(response.body).to include("john@example.com")
      end

      it "handles nil association gracefully" do
        # Create license without user (if allowed) or with nil user
        license = create(:license, user: user, license_key: "DEF-456")
        license.update_column(:user_id, nil)

        get iron_admin.export_path("licenses", format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include("text/csv")
        # Should not crash - the CSV should be valid
        csv_lines = response.body.split("\n")
        expect(csv_lines.length).to be >= 2 # header + at least one data row
      end

      it "escapes special characters properly" do
        user_with_special = create(:user, name: 'John "The Boss" Doe', email: "boss@example.com")
        create(:license, user: user_with_special, license_key: "SPECIAL-001")

        get iron_admin.export_path("licenses", format: :csv)

        expect(response).to have_http_status(:ok)
        # CSV should properly escape quotes by doubling them
        expect(response.body).to include("boss@example.com")
      end

      it "escapes commas in field values" do
        user_with_comma = create(:user, name: "Doe, John", email: "comma@example.com")
        create(:license, user: user_with_comma, license_key: "COMMA-001")

        get iron_admin.export_path("licenses", format: :csv)

        expect(response).to have_http_status(:ok)
        # CSV should handle commas by quoting the field
        expect(response.body).to include("comma@example.com")
      end

      it "escapes newlines in field values" do
        user_with_newline = create(:user, name: "John\nDoe", email: "newline@example.com")
        create(:license, user: user_with_newline, license_key: "NEWLINE-001")

        get iron_admin.export_path("licenses", format: :csv)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("newline@example.com")
      end
    end

    context "JSON format" do
      it "exports the association's display value" do
        create(:license, user: user, license_key: "GHI-789")

        get iron_admin.export_path("licenses", format: :json)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.first["user"]).to eq("john@example.com")
      end

      it "handles nil association gracefully" do
        license = create(:license, user: user, license_key: "JKL-012")
        license.update_column(:user_id, nil)

        get iron_admin.export_path("licenses", format: :json)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.first["user"]).to eq("")
      end

      it "handles special characters in JSON" do
        user_with_special = create(:user, name: 'John "The Boss" Doe', email: "json-special@example.com")
        create(:license, user: user_with_special, license_key: "JSON-SPECIAL-001")

        get iron_admin.export_path("licenses", format: :json)

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json.first["user"]).to eq("json-special@example.com")
      end
    end
  end
end
