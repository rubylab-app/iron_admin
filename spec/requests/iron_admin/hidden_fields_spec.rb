# frozen_string_literal: true

require "rails_helper"

# visible: false hides a field from sort and from audit changes.
RSpec.describe "Hidden fields", type: :request do
  describe "index sort" do
    subject(:titles) { response.parsed_body.css("tbody tr").map { |row| row.text[/(Matching|Other) Doc/] } }

    let(:sort_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = Document

        def self.name
          "HiddenSortDocumentResource"
        end

        def self.resource_name
          "hidden_sort_documents"
        end

        field :password_hash, visible: false
        index_fields :id, :title
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(sort_resource)
      create(:document, title: "Matching Doc", password_hash: "tok_abc123", created_at: 1.day.ago)
      create(:document, title: "Other Doc", password_hash: "zzz_999", created_at: 2.days.ago)
      get iron_admin.resources_path("hidden_sort_documents"),
          params: { sort: "password_hash", direction: "asc" }, as: :html
    end

    # The rejected column is replaced; a valid direction param is kept, so this is created_at asc.
    it "falls back to the default sort column" do
      expect(titles).to eq(["Other Doc", "Matching Doc"])
    end
  end

  describe "audit" do
    let(:audit_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "HiddenAuditUserResource"
        end

        def self.resource_name
          "hidden_audit_users"
        end

        field :role, visible: false

        action :promote do |user|
          user.update!(role: "admin")
        end
      end
    end

    before do
      IronAdmin.configure { |c| c.audit_enabled = true }
      IronAdmin::ResourceRegistry.register(audit_resource)
    end

    it "filters a concealed field in the audit changes" do
      user = create(:user, role: "user")

      post iron_admin.resource_action_path("hidden_audit_users", user, "promote"), as: :html

      expect(IronAdmin::AuditLog.entries.last.changes["role"]).to eq("[FILTERED]")
    end
  end
end
