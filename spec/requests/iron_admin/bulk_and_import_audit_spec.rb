# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Audit events for bulk actions and imports", type: :request do
  let(:events) { [] }

  before do
    IronAdmin.configure do |config|
      config.audit_enabled = true
      config.audit_storage = :database
      config.on_action { |event| events << event }
    end
  end

  describe "POST /:resource_name/bulk_actions/:action_name" do
    subject(:run_bulk_action) do
      post iron_admin.resource_bulk_action_path("audited_licenses", action_name), params: { ids: licenses.map(&:id) }
    end

    let(:licenses) { create_list(:license, 2, status: :active) }
    let(:audit_entries) { IronAdmin::AuditEntry.where(resource: "AuditedLicenseResource") }
    let(:resource_class) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "AuditedLicenseResource"
        end

        def self.resource_name
          "audited_licenses"
        end

        belongs_to :user, display: :email

        bulk_action :revoke_each do |records|
          records.each { |license| license.update!(status: :revoked) }
        end

        bulk_action :revoke_at_once do |records|
          records.update_all(status: :revoked)
        end

        bulk_action :purge do |records, _params|
          records.destroy_all
        end

        bulk_action :refuse do |records|
          records.update_all(status: :revoked)
          false
        end

        bulk_action :explode do |records|
          records.update_all(status: :revoked)
          raise StandardError, "Bulk operation failed"
        end
      end
    end

    before { IronAdmin::ResourceRegistry.register(resource_class) }

    context "when the action saves each record" do
      let(:action_name) { "revoke_each" }

      it "logs one entry per record under the action name" do
        run_bulk_action
        expect(audit_entries.pluck(:action, :record_id)).to match_array(licenses.map { |l| ["revoke_each", l.id] })
      end

      it "records the changes of each record" do
        run_bulk_action
        expect(audit_entries.map { |entry| entry.record_changes["status"] }).to eq([%w[active revoked]] * 2)
      end

      it "passes one event per record to on_action" do
        run_bulk_action
        expect(events.map { |event| [event.action, event.record_id] })
          .to match_array(licenses.map { |l| [:revoke_each, l.id.to_s] })
      end
    end

    context "when the action updates the records in one query" do
      let(:action_name) { "revoke_at_once" }

      it "logs one entry per record" do
        run_bulk_action
        expect(audit_entries.pluck(:record_id)).to match_array(licenses.map(&:id))
      end
    end

    context "when the action destroys the records" do
      let(:action_name) { "purge" }

      it "logs one entry per destroyed record" do
        run_bulk_action
        expect(audit_entries.pluck(:record_id)).to match_array(licenses.map(&:id))
      end
    end

    context "when the action returns false" do
      let(:action_name) { "refuse" }

      it "logs nothing" do
        run_bulk_action
        expect(audit_entries).to be_empty
      end

      it "does not call on_action" do
        run_bulk_action
        expect(events).to be_empty
      end
    end

    context "when the action raises" do
      let(:action_name) { "explode" }

      it "logs nothing" do
        run_bulk_action
        expect(audit_entries).to be_empty
      end
    end

    context "when on_action raises" do
      let(:action_name) { "revoke_each" }

      before { IronAdmin.configure { |config| config.on_action { raise StandardError, "Callback failed" } } }

      it "rolls the action back" do
        run_bulk_action
        expect(License.where(id: licenses.map(&:id)).pluck(:status)).to eq(%w[active active])
      end
    end

    context "when the action changes a password field" do
      subject(:run_bulk_action) do
        post iron_admin.resource_bulk_action_path("audited_documents", "rotate"), params: { ids: documents.map(&:id) }
      end

      let(:documents) { create_list(:document, 2, password_hash: "old_secret") }
      let(:document_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = Document

          def self.name
            "AuditedDocumentResource"
          end

          def self.resource_name
            "audited_documents"
          end

          field :password_hash, type: :password

          bulk_action :rotate do |records|
            records.each { |document| document.update!(password_hash: "new_secret") }
          end
        end
      end

      before { IronAdmin::ResourceRegistry.register(document_resource) }

      it "masks it" do
        run_bulk_action
        changes = IronAdmin::AuditEntry.where(resource: "AuditedDocumentResource").map(&:record_changes)
        expect(changes.pluck("password_hash")).to eq(["[FILTERED]"] * 2)
      end
    end
  end

  describe "POST /:resource_name/import" do
    subject(:run_import) do
      post iron_admin.resource_import_path("audited_import_users"), params: { file: csv_upload(csv) }
    end

    let(:csv) { "Name,Email\nNew,new@example.com\nRenamed,old@example.com\n" }
    let!(:existing_user) { create(:user, name: "Old", email: "old@example.com") }
    let(:audit_entries) { IronAdmin::AuditEntry.where(resource: "AuditedImportUserResource") }
    let(:resource_class) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "AuditedImportUserResource"
        end

        def self.resource_name
          "audited_import_users"
        end

        imports :csv
        import_fields :name, :email
        import_upsert_key :email
        import_transform do |attributes|
          raise StandardError, "Import failed" if attributes[:name] == "Boom"

          attributes
        end
      end
    end

    before { IronAdmin::ResourceRegistry.register(resource_class) }

    it "logs a create entry for each created row" do
      run_import
      expect(audit_entries.where(action: "create").pluck(:record_id)).to eq([User.find_by(email: "new@example.com").id])
    end

    it "logs an update entry for each updated row" do
      run_import
      expect(audit_entries.where(action: "update").pluck(:record_id)).to eq([existing_user.id])
    end

    it "records the changes of each updated row" do
      run_import
      expect(audit_entries.find_by(action: "update").record_changes["name"]).to eq(%w[Old Renamed])
    end

    it "passes one event per saved row to on_action" do
      run_import
      expect(events.map(&:action)).to match_array(%i[create update])
    end

    context "when a row fails validation" do
      let(:csv) { "Name,Email\nNew,new@example.com\n,nameless@example.com\n" }

      it "logs only the saved rows" do
        run_import
        expect(audit_entries.pluck(:record_id)).to eq([User.find_by(email: "new@example.com").id])
      end
    end

    context "when the import fails part-way and rolls back" do
      let(:csv) { "Name,Email\nNew,new@example.com\nBoom,boom@example.com\n" }

      it "logs nothing" do
        run_import
        expect(audit_entries).to be_empty
      end
    end

    context "when on_action raises" do
      before { IronAdmin.configure { |config| config.on_action { raise StandardError, "Callback failed" } } }

      it "rolls the import back" do
        expect { run_import }.not_to change(User, :count)
      end
    end

    context "with many rows" do
      let(:row_count) { 10 }

      it "adds one query per row: the audit insert" do
        IronAdmin.configuration.audit_enabled = false
        unaudited = sql_queries_during { post_import_of(row_count, "unaudited") }
        IronAdmin.configuration.audit_enabled = true
        audited = sql_queries_during { post_import_of(row_count, "audited") }

        expect(audited - unaudited).to eq(row_count)
      end
    end
  end

  def csv_upload(contents)
    Rack::Test::UploadedFile.new(StringIO.new(contents), "text/csv", true, original_filename: "users.csv")
  end

  # Imports the given number of new users, with emails unique to the prefix.
  def post_import_of(rows, prefix)
    lines = Array.new(rows) { |i| "User #{i},#{prefix}#{i}@example.com\n" }
    csv = "Name,Email\n#{lines.join}"
    post iron_admin.resource_import_path("audited_import_users"), params: { file: csv_upload(csv) }
  end

  # Counts the SQL statements run by the block, leaving out schema lookups,
  # transaction control and query cache hits.
  def sql_queries_during(&)
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name])
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end
