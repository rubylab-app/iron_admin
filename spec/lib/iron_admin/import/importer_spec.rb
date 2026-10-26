# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Import::Importer do
  let(:resource_class) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name
        "ImportUserResource"
      end

      def self.resource_name
        "import_users"
      end

      imports :csv, :json
      import_fields :name, :email, :active, :preferences
      import_upsert_key :email
    end
  end

  let(:tenant_scoped_license_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = License

      def self.name
        "TenantScopedImportLicenseResource"
      end

      def self.resource_name
        "tenant_scoped_import_licenses"
      end

      belongs_to :user, display: :email

      imports :csv
      import_fields :license_key, :status, :license_type, :max_devices, :expires_at
      import_upsert_key :license_key
    end
  end

  it "builds a preview with mapped, type-cast row attributes" do
    csv = StringIO.new(%(Name,Email,Active,Preferences\nJane,jane@example.com,false,"{""tier"":""gold""}"\n))

    preview = described_class.new(resource_class, file: csv, format: :csv).preview

    expect(preview.total_rows).to eq(1)
    expect(preview.mapping).to include("Name" => :name, "Email" => :email)
    expect(preview.rows.first.attributes).to include(
      name: "Jane",
      email: "jane@example.com",
      active: false,
      preferences: { "tier" => "gold" }
    )
  end

  describe "#preview" do
    subject(:preview) { described_class.new(resource_class, file: csv, format: :csv).preview }

    context "with mapped columns" do
      let(:csv) { StringIO.new("Email,Active,Unknown\njane@example.com,0,x\n") }

      it "carries the field of each mapped column, so the page can format its cells" do
        expect(preview.fields.transform_values(&:type)).to eq(email: :email, active: :boolean)
      end

      it "keeps the type-cast value the import saves" do
        expect(preview.rows.first.attributes[:active]).to be(false)
      end

      it "formats the cell as the show page labels the field" do
        expect(preview.cell_text(preview.rows.first, :active)).to eq("No")
      end
    end

    context "when a row matches an existing record on the upsert key" do
      let(:csv) { StringIO.new("Name,Email\nJane,jane@example.com\n") }

      before { create(:user, name: "Old", email: "jane@example.com") }

      it "validates the row against the existing record" do
        expect(preview.rows.first.errors).to be_empty
      end

      it "leaves the existing record unchanged" do
        preview

        expect(User.find_by(email: "jane@example.com").name).to eq("Old")
      end
    end

    context "when a new row reuses a unique value of another record" do
      let(:resource_class) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "NameKeyedImportUserResource"
          end

          def self.resource_name
            "name_keyed_import_users"
          end

          imports :csv
          import_fields :name, :email
          import_upsert_key :name
        end
      end
      let(:csv) { StringIO.new("Name,Email\nNew Jane,jane@example.com\n") }

      before { create(:user, name: "Jane", email: "jane@example.com") }

      it "still reports the uniqueness error" do
        expect(preview.rows.first.errors.map(&:message)).to include("Email has already been taken")
      end
    end

    context "when the file has more rows than max_rows" do
      let(:csv) { StringIO.new("Name,Email\nJane,jane@example.com\nJohn,john@example.com\n") }

      before { resource_class.import_options(max_rows: 1) }

      it "rejects the file before rendering it" do
        expect { preview }.to raise_error(ArgumentError, /exceeding the 1 row limit/)
      end
    end
  end

  it "creates records from CSV rows" do
    csv = StringIO.new(%(Name,Email,Active\nJane,jane@example.com,true\n))

    result = nil
    expect do
      result = described_class.new(resource_class, file: csv, format: :csv).execute!
    end.to change(User, :count).by(1)

    expect(result.created_count).to eq(1)
    expect(result.updated_count).to eq(0)
    expect(User.last).to have_attributes(name: "Jane", email: "jane@example.com", active: true)
  end

  it "upserts existing records using the configured key" do
    create(:user, name: "Old", email: "jane@example.com", active: true)
    csv = StringIO.new(%(Name,Email,Active\nJane,jane@example.com,false\n))

    result = nil
    expect do
      result = described_class.new(resource_class, file: csv, format: :csv).execute!
    end.not_to change(User, :count)

    expect(result.created_count).to eq(0)
    expect(result.updated_count).to eq(1)
    expect(User.find_by(email: "jane@example.com")).to have_attributes(name: "Jane", active: false)
  end

  it "uses the adapter upsert hook when no tenant scope is configured" do
    found_record = Object.new
    fake_adapter = Class.new do
      attr_reader :lookup

      def initialize(found_record)
        @found_record = found_record
      end

      def find_by_keys(lookup)
        @lookup = lookup
        @found_record
      end

      def all
        raise "expected importer to use find_by_keys for unscoped upserts"
      end
    end.new(found_record)

    allow(resource_class).to receive(:adapter).and_return(fake_adapter)

    importer = described_class.new(resource_class, file: StringIO.new(""), format: :csv)
    expect(importer.send(:find_existing_record, email: "jane@example.com")).to eq(found_record)
    expect(fake_adapter.lookup).to eq(email: "jane@example.com")
  end

  it "does not upsert records outside the tenant scope" do
    active_user = create(:user, active: true)
    inactive_user = create(:user, active: false)
    create(:license, user: active_user, license_key: "IN-TENANT", status: :active, license_type: "standard")
    outside_license = create(:license, user: inactive_user, license_key: "OUT-OF-TENANT", status: :active, license_type: "standard")
    csv = StringIO.new(%(License key,Status,License type\nOUT-OF-TENANT,revoked,enterprise\n))

    IronAdmin.configure do |config|
      config.tenant_scope do |scope|
        scope.joins(:user).where(users: { active: true })
      end
    end

    result = described_class.new(tenant_scoped_license_resource, file: csv, format: :csv).execute!

    expect(result.created_count).to eq(0)
    expect(result.updated_count).to eq(0)
    expect(result.failed_count).to be >= 1
    expect(outside_license.reload.status).to eq("active")
    expect(outside_license.license_type).to eq("standard")
  end

  it "collects validation errors without persisting invalid rows" do
    csv = StringIO.new("Name,Email\n,missing@example.com\n")

    result = described_class.new(resource_class, file: csv, format: :csv).execute!

    expect(result.created_count).to eq(0)
    expect(result.failed_count).to eq(1)
    expect(result.errors.first.message).to include("Name")
  end

  describe "#execute!" do
    context "with a block" do
      subject(:saved) do
        yielded = []
        described_class.new(resource_class, file: csv, format: :csv).execute! do |action, record|
          yielded << [action, record.email, record.saved_changes.key?("name")]
        end
        yielded
      end

      let(:csv) { StringIO.new("Name,Email\nNew,new@example.com\nRenamed,old@example.com\n,invalid@example.com\n") }

      before { create(:user, name: "Old", email: "old@example.com") }

      it "yields each saved row's action and record, with its changes, and skips failed rows" do
        expect(saved).to eq([[:create, "new@example.com", true], [:update, "old@example.com", true]])
      end
    end

    context "when a callback aborts the save" do
      subject(:result) do
        described_class.new(aborting_resource, file: csv, format: :csv).execute! { |*row| yielded << row }
      end

      let(:yielded) { [] }
      let(:csv) { StringIO.new("Name,Email\nNew,new@example.com\nRenamed,old@example.com\n") }
      let(:aborting_resource) do
        aborting_user = Class.new(User) do
          def self.name
            "User"
          end

          before_create { throw :abort }
          before_update { throw :abort }
        end

        Class.new(IronAdmin::Resource) do
          self.model_class_override = aborting_user

          def self.name
            "AbortingImportUserResource"
          end

          def self.resource_name
            "aborting_import_users"
          end

          imports :csv
          import_fields :name, :email
          import_upsert_key :email
        end
      end

      before { create(:user, name: "Old", email: "old@example.com") }

      it "counts the created and the updated row as failed" do
        expect(result.failed_count).to eq(2)
      end

      it "reports that the records could not be saved" do
        expect(result.errors.map(&:message)).to eq(["The record could not be saved."] * 2)
      end

      it "does not yield the rows" do
        result
        expect(yielded).to be_empty
      end
    end
  end
end
