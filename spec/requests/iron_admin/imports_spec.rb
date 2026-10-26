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

    it "submits the upload form outside Turbo Drive so the preview page can render" do
      get iron_admin.resource_import_path("request_import_users"), as: :html

      preview_path = iron_admin.resource_import_preview_path("request_import_users")
      upload_form = html.at_css(%(form[action="#{preview_path}"]))
      expect(upload_form["data-turbo"]).to eq("false")
    end
  end

  describe "importing from the preview page" do
    let(:csv) { "Name,Email\nJane,jane@example.com\nJohn,john@example.com\n" }

    before do
      post iron_admin.resource_import_preview_path("request_import_users"),
           params: { file: upload(csv, "users.csv", "text/csv") }
    end

    it "renders an import form that posts to the create route" do
      expect(import_form).to be_present
    end

    it "labels the import button with the number of rows to import" do
      expect(import_form.at_css("button[type=submit]").text.squish).to eq("Import 2 rows")
    end

    it "creates every previewed row without uploading the file again" do
      expect { submit_import_form }.to change(User, :count).by(2)
    end

    it "redirects to the resource index with the import summary" do
      submit_import_form

      expect(response).to redirect_to(iron_admin.resources_path("request_import_users"))
      expect(flash[:notice]).to eq("Import finished: 2 created, 0 updated, 0 failed.")
    end

    context "when the previewed file holds multi-line and non-ASCII values" do
      let(:csv) { %(Name,Email\n"José\nPérez",jose@example.com\n) }

      it "imports the values byte for byte" do
        submit_import_form

        expect(User.find_by(email: "jose@example.com").name).to eq("José\nPérez")
      end
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

    it "rejects a file with more rows than the import row limit" do
      import_resource.import_options(max_rows: 1)

      post iron_admin.resource_import_preview_path("request_import_users"),
           params: { file: upload("Name,Email\nJane,jane@example.com\nJohn,john@example.com\n", "users.csv", "text/csv") }

      expect(flash[:alert]).to include("exceeding the 1 row limit")
    end

    context "when the file param is a plain string instead of an upload" do
      let(:server_file) { Rails.root.join("tmp/imports_spec_server_file.csv") }

      before do
        FileUtils.mkdir_p(server_file.dirname)
        File.write(server_file, "Name,Email\nServer,server-secret@example.com\n")
      end

      after { FileUtils.rm_f(server_file) }

      it "does not read the named file from the server" do
        post iron_admin.resource_import_preview_path("request_import_users"),
             params: { import_format: "csv", file: server_file.to_s }

        expect(response).to redirect_to(iron_admin.resource_import_path("request_import_users"))
        expect(response.body).not_to include("server-secret@example.com")
      end
    end
  end

  describe "POST /:resource_name/import" do
    it "redirects to the upload form when the carried import data is not valid Base64" do
      post iron_admin.resource_import_path("request_import_users"),
           params: { import_format: "csv", import_data: "not base64!" }

      expect(response).to redirect_to(iron_admin.resource_import_path("request_import_users"))
      expect(flash[:alert]).to eq("Choose a file to import.")
    end

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

    context "when the file param is a plain string instead of an upload" do
      let(:server_file) { Rails.root.join("tmp/imports_spec_server_file.csv") }

      before do
        FileUtils.mkdir_p(server_file.dirname)
        File.write(server_file, "Name,Email\nServer,server-secret@example.com\n")
      end

      after { FileUtils.rm_f(server_file) }

      it "does not import the named file from the server" do
        expect do
          post iron_admin.resource_import_path("request_import_users"),
               params: { import_format: "csv", file: server_file.to_s }
        end.not_to change(User, :count)
      end
    end
  end

  def upload(contents, filename, content_type)
    Rack::Test::UploadedFile.new(StringIO.new(contents), content_type, true, original_filename: filename)
  end

  def html
    Nokogiri::HTML(response.body)
  end

  def import_form
    create_path = iron_admin.resource_import_path("request_import_users")
    html.at_css(%(form[method="post"][action="#{create_path}"]))
  end

  # Submits the preview page's import form the way a browser would: only the
  # fields rendered in the form are sent, so nothing is uploaded again, and
  # every line break in a value is sent as CRLF, as HTML form submission does.
  def submit_import_form
    form = import_form
    fields = form.css("input[name]").to_h do |input|
      [input["name"], input["value"].to_s.gsub(/\r\n?|\n/, "\r\n")]
    end
    post form["action"], params: fields
  end
end
