# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Import::ColumnMapper do
  let(:resource_class) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name
        "ImportMappingUserResource"
      end

      def self.resource_name
        "import_mapping_users"
      end

      imports :csv
      import_fields :name, :email, :active, :preferences
    end
  end

  it "maps exact and humanized source headers to importable fields" do
    mapping = described_class.new(resource_class).map_headers(%w[Name email Active Preferences])

    expect(mapping).to eq(
      "Name" => :name,
      "email" => :email,
      "Active" => :active,
      "Preferences" => :preferences
    )
  end

  it "does not map headers for fields excluded from the import allowlist" do
    mapping = described_class.new(resource_class).map_headers(["Name", "Role", "Created at"])

    expect(mapping).to eq("Name" => :name)
  end
end
