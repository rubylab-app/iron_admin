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

  describe "POST /:resource_name/import/preview display" do
    def preview_csv(contents)
      post iron_admin.resource_import_preview_path("request_import_users"),
           params: { file: upload(contents, "users.csv", "text/csv") }
    end

    def preview_cells
      html.css("tbody tr").map { |row| row.css("td").map { |cell| cell.text.strip } }
    end

    it "renders text values without Ruby inspect quotes" do
      preview_csv("Name,Email\nJane,jane@example.com\n")

      expect(preview_cells.first.first(2)).to eq(["Jane", "jane@example.com"])
    end

    it "renders missing values as empty cells" do
      preview_csv("Name,Email,Active\nJane,jane@example.com,\n")

      expect(preview_cells.first[2]).to eq("")
    end

    it "renders JSON values as JSON" do
      preview_csv(%(Name,Email,Preferences\nJane,jane@example.com,"{""tier"":""gold""}"\n))

      expect(preview_cells.first[2]).to eq(%({"tier":"gold"}))
    end

    it "uses the singular summary for a single row" do
      preview_csv("Name,Email\nJane,jane@example.com\n")

      expect(html.at_css("h1 + p").text).to eq("1 row detected.")
    end

    it "uses the plural summary for several rows" do
      preview_csv("Name,Email\nJane,jane@example.com\nJohn,john@example.com\n")

      expect(html.at_css("h1 + p").text).to eq("2 rows detected.")
    end

    it "marks a row matching an existing record on the upsert key as valid" do
      create(:user, name: "Old", email: "jane@example.com")

      preview_csv("Name,Email\nJane,jane@example.com\n")

      expect(preview_cells.first.last).to eq("Valid")
    end

    context "with a datetime field" do
      let(:license_import_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "RequestImportLicenseResource"
          end

          def self.resource_name
            "request_import_licenses"
          end

          imports :csv
          import_fields :license_key, :expires_at
        end
      end

      before { IronAdmin::ResourceRegistry.register(license_import_resource) }

      it "renders the localized time instead of the TimeWithZone inspect output" do
        post iron_admin.resource_import_preview_path("request_import_licenses"),
             params: { file: upload("License key,Expires at\nKEY-1,2026-10-20 10:00:00\n", "licenses.csv", "text/csv") }

        expect(preview_cells.first[1]).to eq(I18n.l(Time.zone.parse("2026-10-20 10:00:00")))
      end
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

  describe "POST /:resource_name/import/preview errors" do
    it "redirects when the file is missing" do
      post iron_admin.resource_import_preview_path("request_import_users")

      expect(response).to redirect_to(iron_admin.resource_import_path("request_import_users"))
    end

    it "reports an unsupported format" do
      post iron_admin.resource_import_preview_path("request_import_users"),
           params: { format: "xml", file: upload("<row/>", "users.xml", "application/xml") }

      expect(flash[:alert]).to include("Unsupported import format")
    end

    it "reports an unexpected parse failure" do
      post iron_admin.resource_import_preview_path("request_import_users"),
           params: { file: upload("\"unterminated", "users.csv", "text/csv") }

      expect(flash[:alert]).to eq("Something went wrong. Please try again.")
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

    it "redirects when the file is missing" do
      post iron_admin.resource_import_path("request_import_users")

      expect(response).to redirect_to(iron_admin.resource_import_path("request_import_users"))
    end

    it "reports an unsupported format" do
      post iron_admin.resource_import_path("request_import_users"),
           params: { format: "xml", file: upload("<row/>", "users.xml", "application/xml") }

      expect(flash[:alert]).to include("Unsupported import format")
    end

    it "reports an unexpected parse failure" do
      post iron_admin.resource_import_path("request_import_users"),
           params: { file: upload("\"unterminated", "users.csv", "text/csv") }

      expect(flash[:alert]).to eq("Something went wrong. Please try again.")
    end
  end

  def upload(contents, filename, content_type)
    Rack::Test::UploadedFile.new(StringIO.new(contents), content_type, true, original_filename: filename)
  end

  def html
    Nokogiri::HTML(response.body)
  end
end
