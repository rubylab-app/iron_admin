# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Import authorization per row", type: :request do
  let(:resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name = "CreateOnlyImportResource"
      def self.resource_name = "create_only_users"

      imports :csv
      import_fields :name, :email
      import_upsert_key :email

      policy do
        allow :read, :create
      end
    end
  end
  let(:csv) { "Name,Email\nRenamed,taken@example.com\nNew Person,new@example.com\n" }

  before do
    IronAdmin::ResourceRegistry.register(resource)
    create(:user, name: "Original", email: "taken@example.com")
  end

  def upload(contents)
    Rack::Test::UploadedFile.new(StringIO.new(contents), "text/csv", true, original_filename: "users.csv")
  end

  it "does not update a matched record when the policy allows only :create" do
    post iron_admin.resource_import_path("create_only_users"), params: { file: upload(csv) }

    expect(User.find_by(email: "taken@example.com").name).to eq("Original")
  end

  it "still creates the rows that match no record" do
    expect do
      post iron_admin.resource_import_path("create_only_users"), params: { file: upload(csv) }
    end.to change(User, :count).by(1)
  end

  it "counts the denied row as failed" do
    post iron_admin.resource_import_path("create_only_users"), params: { file: upload(csv) }

    expect(flash[:notice]).to eq("Import finished: 1 created, 0 updated, 1 failed.")
  end

  it "reports the denied row in the preview" do
    post iron_admin.resource_import_preview_path("create_only_users"), params: { file: upload(csv) }

    expect(response.body).to include("You are not allowed to update this record.")
  end
end
