# frozen_string_literal: true

require "rails_helper"

# The UI never shows a :password or :hidden field, so no search, sort or
# autocomplete may let a reader probe its value one character at a time.
RSpec.describe "Secret fields", type: :request do
  let(:secret_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = Document

      def self.name
        "SecretFieldDocumentResource"
      end

      def self.resource_name
        "secret_field_documents"
      end

      field :password_hash, type: :password
      index_fields :id, :title
    end
  end

  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(secret_resource)
    create(:document, title: "Matching Doc", password_hash: "tok_abc123", created_at: 1.day.ago)
    create(:document, title: "Other Doc", password_hash: "zzz_999", created_at: 2.days.ago)
  end

  describe "index search" do
    context "with a field query on the secret field" do
      before do
        get iron_admin.resources_path("secret_field_documents"), params: { q: "password_hash:zzz" }, as: :html
      end

      it "does not filter on it" do
        expect(response.body).to include("Matching Doc")
      end
    end

    # Without `searchable`, every string column is searchable, password_hash included.
    context "with a query that only the secret value matches" do
      before { get iron_admin.resources_path("secret_field_documents"), params: { q: "tok_a" }, as: :html }

      it "does not search the secret field" do
        expect(response.body).not_to include("Matching Doc")
      end
    end
  end

  describe "index search on a :hidden field" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::WidgetResource)
      create(:widget, name: "Live Widget", secret_token: "sk_live_w123")
      create(:widget, name: "Test Widget", secret_token: "sk_test_w456")
      get iron_admin.resources_path("widgets"), params: { q: "secret_token:sk_live" }, as: :html
    end

    it "does not filter on it" do
      expect(response.body).to include("Test Widget")
    end
  end

  describe "index sort" do
    subject(:titles) { response.parsed_body.css("tbody tr").map { |row| row.text[/(Matching|Other) Doc/] } }

    before do
      get iron_admin.resources_path("secret_field_documents"),
          params: { sort: "password_hash", direction: "asc" }, as: :html
    end

    it "falls back to the default sort column" do
      expect(titles).to eq(["Other Doc", "Matching Doc"])
    end
  end

  describe "export" do
    before do
      get iron_admin.export_path("secret_field_documents", format: :csv), params: { q: "password_hash:zzz" }
    end

    it "does not filter on the secret field" do
      expect(response.body).to include("Matching Doc")
    end
  end

  describe "global search" do
    before { get iron_admin.search_path(q: "tok_a") }

    it "does not search the secret field" do
      expect(response.body).not_to include("Matching Doc")
    end
  end

  describe "autocomplete" do
    # The display attribute is not a column, so autocomplete falls back to the
    # first searchable column.
    let(:secret_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = Document

        def self.name
          "SecretAutocompleteDocumentResource"
        end

        def self.resource_name
          "secret_field_documents"
        end

        def self.display_attribute
          :headline
        end

        field :password_hash, type: :password
        searchable :password_hash, :title
      end
    end

    before { get iron_admin.autocomplete_path("secret_field_documents"), params: { q: "tok" }, as: :json }

    it "never labels a suggestion with the secret value" do
      expect(response.body).not_to include("tok_abc123")
    end
  end
end
