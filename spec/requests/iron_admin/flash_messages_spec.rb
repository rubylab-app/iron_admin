# frozen_string_literal: true

require "rails_helper"

# Checks the page the user lands on, not just flash[:notice]: the dummy app
# overrides the engine layout with a bare one (see layout_spec.rb), so this
# spec puts the engine's views first to render the real shell.
RSpec.describe "Flash messages in the admin layout", type: :request do
  around do |example|
    original_view_paths = IronAdmin::ApplicationController.view_paths
    IronAdmin::ApplicationController.prepend_view_path(IronAdmin::Engine.root.join("app/views"))
    example.run
  ensure
    IronAdmin::ApplicationController.view_paths = original_view_paths
  end

  # The messages shown with the given ARIA role on the page the redirect leads to.
  def messages_after_redirect(role)
    follow_redirect!
    Nokogiri::HTML(response.body).css(".overflow-auto [role='#{role}']").map { |alert| alert.text.squish }
  end

  def upload(contents, filename, content_type)
    Rack::Test::UploadedFile.new(StringIO.new(contents), content_type, true, original_filename: filename)
  end

  describe "resource CRUD notices" do
    let(:user) { create(:user) }

    it "shows the created notice" do
      post iron_admin.resources_path("users"), params: { record: { name: "Ana", email: "ana@example.com" } }

      expect(messages_after_redirect("status")).to eq(["User created."])
    end

    it "shows the updated notice" do
      patch iron_admin.resource_path("users", user), params: { record: { name: "Ana Updated" } }

      expect(messages_after_redirect("status")).to eq(["User updated."])
    end

    it "shows the deleted notice" do
      delete iron_admin.resource_path("users", user)

      expect(messages_after_redirect("status")).to eq(["User deleted."])
    end
  end

  describe "member action messages" do
    let(:license) { create(:license) }
    let(:failing_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name = "FlashFailingLicenseResource"
        def self.resource_name = "flash_failing_licenses"

        action(:explode) { |_license| raise "boom" }
      end
    end

    it "shows the action completed notice" do
      post iron_admin.resource_action_path("licenses", license, "revoke")

      expect(messages_after_redirect("status")).to eq(["Action completed"])
    end

    it "shows the generic error alert when the action raises" do
      IronAdmin::ResourceRegistry.register(failing_resource)
      post iron_admin.resource_action_path("flash_failing_licenses", license, "explode")

      expect(messages_after_redirect("alert")).to eq(["Something went wrong. Please try again."])
    end
  end

  describe "bulk action messages" do
    let(:license) { create(:license) }

    it "shows the success notice" do
      post iron_admin.resource_bulk_action_path("licenses", "export"), params: { ids: [license.id] }

      expect(messages_after_redirect("status")).to eq(["Bulk action completed"])
    end

    it "shows the inaccessible records alert" do
      post iron_admin.resource_bulk_action_path("licenses", "export"), params: { ids: [license.id, 999_999] }

      expect(messages_after_redirect("alert")).to eq(["Some records are not accessible"])
    end

    # The form sits inside turbo-frame#records. Submitted to that frame, Turbo
    # would keep only the frame of the page the redirect leads to and drop the
    # message the shell renders outside it.
    it "submits the bulk form to the whole page" do
      license
      get iron_admin.resources_path("licenses")

      expect(Nokogiri::HTML(response.body).at_css("form#bulk-actions-form")["data-turbo-frame"]).to eq("_top")
    end
  end

  describe "import messages" do
    let(:import_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "FlashImportUserResource"
        def self.resource_name = "flash_import_users"

        imports :csv
        import_fields :name, :email
      end
    end

    before { IronAdmin::ResourceRegistry.register(import_resource) }

    it "shows the import result notice" do
      post iron_admin.resource_import_path("flash_import_users"),
           params: { file: upload("name,email\nJane,jane@example.com\n", "users.csv", "text/csv") }

      expect(messages_after_redirect("status")).to eq(["Import finished: 1 created, 0 updated, 0 failed."])
    end

    it "shows the missing file alert" do
      post iron_admin.resource_import_preview_path("flash_import_users"), params: { import_format: "csv" }

      expect(messages_after_redirect("alert")).to eq(["Choose a file to import."])
    end
  end

  describe "tool messages" do
    let(:tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "FlashCacheTool"

        menu label: "Flash Cache"

        tool_action :clear_cache

        def clear_cache(ctx)
          ctx.flash[:notice] = "Cache cleared!"
        end
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    it "shows the notice the tool sets" do
      post iron_admin.tool_action_path("flash_cache", "clear_cache")

      expect(messages_after_redirect("status")).to eq(["Cache cleared!"])
    end
  end
end
