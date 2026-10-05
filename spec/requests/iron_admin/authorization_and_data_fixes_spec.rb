# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authorization and data-handling fixes", type: :request do
  def upload(contents, filename, content_type)
    Rack::Test::UploadedFile.new(StringIO.new(contents), content_type, true, original_filename: filename)
  end

  describe "read authorization" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "DeniedReadResource"
        def self.resource_name = "denied_read_users"

        policy { deny :read }
      end
    end

    before do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(resource)
    end

    it "forbids the index" do
      create(:user, name: "Secret Index User")

      get iron_admin.resources_path("denied_read_users"), as: :html

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids export" do
      create(:user, email: "secret-export@example.com")

      get iron_admin.export_path("denied_read_users", format: :csv)

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids autocomplete" do
      get iron_admin.autocomplete_path("denied_read_users"), params: { q: "sec" }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it "omits the resource from global search" do
      create(:user, name: "SearchDeniedPerson")

      get iron_admin.search_path, params: { q: "SearchDeniedPerson" }, as: :html

      expect(response.body).not_to include("SearchDeniedPerson")
    end
  end

  describe "deny_actions :delete" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "DeniedDeleteResource"
        def self.resource_name = "denied_delete_users"

        deny_actions :delete
      end
    end

    before { IronAdmin::ResourceRegistry.register(resource) }

    it "does not destroy the record" do
      user = create(:user)

      expect do
        delete iron_admin.resource_path("denied_delete_users", user), as: :html
      end.not_to change(User, :count)
    end
  end

  describe "import authorization" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "DeniedImportResource"
        def self.resource_name = "denied_import_users"

        imports :csv
        import_fields :name, :email
        policy { deny :create }
      end
    end

    before { IronAdmin::ResourceRegistry.register(resource) }

    it "does not create records when create is denied" do
      file = upload("Name,Email\nImported,imported-denied@example.com\n", "users.csv", "text/csv")

      expect do
        post iron_admin.resource_import_path("denied_import_users"), params: { format: "csv", file: file }
      end.not_to change(User, :count)
    end
  end

  describe "readonly mass assignment" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "ReadonlyRoleResource"
        def self.resource_name = "readonly_role_users"

        field :role, readonly: true
      end
    end

    before { IronAdmin::ResourceRegistry.register(resource) }

    it "does not persist a readonly field" do
      user = create(:user, role: "member")

      patch iron_admin.resource_path("readonly_role_users", user),
            params: { record: { name: user.name, email: user.email, role: "admin" } },
            as: :html

      expect(user.reload.role).to eq("member")
    end
  end

  describe "csv formula neutralization" do
    it "prefixes cells that start with a formula character" do
      create(:user, name: "=cmd|' /C calc'!A0", email: "formula@example.com")

      get iron_admin.export_path("users", format: :csv)

      expect(response.body).to include("'=cmd")
    end
  end

  describe "datetime search bounds" do
    it "includes records created later on the end date" do
      user = create(:user)
      late = create(:license, user: user, created_at: Time.zone.now.end_of_day - 1.minute)
      today = Date.current.to_s

      get iron_admin.resources_path("licenses"), params: { q: "created_at:#{today}..#{today}" }, as: :html

      expect(response.body).to include(late.license_key)
    end
  end

  describe "bulk actions on a composite primary key" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = Membership

        def self.name = "MembershipBulkResource"
        def self.resource_name = "membership_bulk_resources"

        bulk_action :rename do |records|
          records.update_all(role: "member")
        end
      end
    end

    before { IronAdmin::ResourceRegistry.register(resource) }

    it "updates the selected membership" do
      record = Membership.create!(account_id: 7, scope_id: 13, role: "admin")

      post iron_admin.resource_bulk_action_path("membership_bulk_resources", "rename"),
           params: { ids: [record.to_param] },
           as: :html

      expect(record.reload.role).to eq("member")
    end
  end

  describe "bulk actions on a slug primary key" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = SluggedResource

        def self.name = "SlugBulkResource"
        def self.resource_name = "slug_bulk_resources"

        bulk_action :touch_title do |records|
          records.update_all(title: "touched")
        end
      end
    end

    before { IronAdmin::ResourceRegistry.register(resource) }

    it "updates the selected record" do
      record = SluggedResource.create!(slug: "hello", title: "Hello")

      post iron_admin.resource_bulk_action_path("slug_bulk_resources", "touch_title"),
           params: { ids: [record.to_param] },
           as: :html

      expect(record.reload.title).to eq("touched")
    end
  end
end
