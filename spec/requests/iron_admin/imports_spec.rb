# frozen_string_literal: true

require "rails_helper"

RSpec.describe "IronAdmin::Imports", type: :request do
  let(:import_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name
        "RequestImportUserResource"
      end

      def self.resource_name
        "request_import_users"
      end

      imports :csv, :json
      import_fields :name, :email, :active, :preferences
      import_upsert_key :email
    end
  end

  before do
    IronAdmin::ResourceRegistry.register(import_resource)
  end

  describe "GET /:resource_name" do
    it "renders an import button for import-enabled resources" do
      get iron_admin.resources_path("request_import_users"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Import")
      expect(response.body).to include(iron_admin.resource_import_path("request_import_users"))
    end
  end

  describe "GET /:resource_name/import" do
    it "renders the upload form for import-enabled resources" do
      get iron_admin.resource_import_path("request_import_users"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('type="file"')
      expect(response.body).to include("CSV")
      expect(response.body).to include("JSON")
    end

    it "returns not found for resources without imports enabled" do
      get iron_admin.resource_import_path("users"), as: :html

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /:resource_name/import/preview" do
    it "previews CSV uploads" do
      post iron_admin.resource_import_preview_path("request_import_users"),
           params: { format: "csv", file: upload("Name,Email\nJane,jane@example.com\n", "users.csv", "text/csv") }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jane")
      expect(response.body).to include("jane@example.com")
    end

    it "previews JSON uploads" do
      post iron_admin.resource_import_preview_path("request_import_users"),
           params: {
             format: "json",
             file: upload(%([{"Name":"Jane","Email":"jane@example.com"}]), "users.json", "application/json"),
           }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jane")
      expect(response.body).to include("jane@example.com")
    end
  end

  describe "POST /:resource_name/import" do
    it "creates records from uploaded CSV data" do
      expect do
        post iron_admin.resource_import_path("request_import_users"),
             params: { format: "csv", file: upload("Name,Email\nJane,jane@example.com\n", "users.csv", "text/csv") }
      end.to change(User, :count).by(1)

      expect(response).to redirect_to(iron_admin.resources_path("request_import_users"))
      expect(User.last).to have_attributes(name: "Jane", email: "jane@example.com")
    end

    it "upserts records from uploaded CSV data" do
      create(:user, name: "Old", email: "jane@example.com")

      expect do
        post iron_admin.resource_import_path("request_import_users"),
             params: { format: "csv", file: upload("Name,Email\nJane,jane@example.com\n", "users.csv", "text/csv") }
      end.not_to change(User, :count)

      expect(User.find_by(email: "jane@example.com").name).to eq("Jane")
    end
  end

  def upload(contents, filename, content_type)
    Rack::Test::UploadedFile.new(StringIO.new(contents), content_type, true, original_filename: filename)
  end
end
