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

  it "collects validation errors without persisting invalid rows" do
    csv = StringIO.new("Name,Email\n,missing@example.com\n")

    result = described_class.new(resource_class, file: csv, format: :csv).execute!

    expect(result.created_count).to eq(0)
    expect(result.failed_count).to eq(1)
    expect(result.errors.first.message).to include("Name")
  end
end
