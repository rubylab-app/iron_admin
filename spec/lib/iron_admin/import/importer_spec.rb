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
end
