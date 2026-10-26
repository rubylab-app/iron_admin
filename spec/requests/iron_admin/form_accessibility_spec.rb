# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Form control accessible names", type: :request do
  let(:page_html) do
    get path, headers: { "Accept" => "text/html" }
    response.body
  end
  let(:document) { Nokogiri::HTML5(page_html) }

  shared_examples "a page whose form controls are all named" do
    it "renders form controls" do
      expect(document.css("input:not([type=hidden]), select, textarea")).to be_present
    end

    it "names every control and points every label at one" do
      expect(form_accessibility_problems(page_html)).to be_empty
    end
  end

  describe "the forms of the dummy resources" do
    dummy_records = {
      "users" => -> { create(:user) },
      "licenses" => -> { create(:license) },
      "posts" => -> { create(:post).tap { create_list(:tag, 2) } },
      "documents" => lambda {
        create(:document).tap do |document|
          document.cover_image.attach(io: StringIO.new("cover"), filename: "cover.txt", content_type: "text/plain")
          document.attachments.attach(io: StringIO.new("doc"), filename: "doc.txt", content_type: "text/plain")
        end
      },
      "profiles" => -> { create(:profile) },
      "tags" => -> { create(:tag) },
      "notes" => -> { Note.create!(title: "Note", notable: create(:user)) },
      "widgets" => -> { create(:widget, permissions: "read,write") },
      "memberships" => -> { Membership.create!(account_id: 7, scope_id: 13, role: "admin") },
      "slugged_resources" => -> { SluggedResource.create!(slug: "first", title: "First") },
    }

    before do
      [
        IronAdmin::Resources::PostResource, IronAdmin::Resources::DocumentResource,
        IronAdmin::Resources::ProfileResource, IronAdmin::Resources::TagResource,
        IronAdmin::Resources::WidgetResource,
        IronAdmin::Resources::MembershipResource, IronAdmin::Resources::SluggedResourceResource,
      ].each { |resource| IronAdmin::ResourceRegistry.register(resource) }
    end

    dummy_records.each do |resource_name, build_record|
      describe "the new #{resource_name} form" do
        let(:path) { iron_admin.new_resource_path(resource_name) }

        before { instance_exec(&build_record) } # Gives belongs_to, has_many and polymorphic selects options.

        it_behaves_like "a page whose form controls are all named"
      end

      describe "the edit #{resource_name} form" do
        let(:path) { iron_admin.edit_resource_path(resource_name, instance_exec(&build_record).to_param) }

        it_behaves_like "a page whose form controls are all named"
      end
    end
  end

  describe "the names of associated and grouped controls" do
    before do
      [IronAdmin::Resources::PostResource, IronAdmin::Resources::ProfileResource, IronAdmin::Resources::WidgetResource]
        .each { |resource| IronAdmin::ResourceRegistry.register(resource) }
    end

    context "with a belongs_to select" do
      let(:path) { iron_admin.edit_resource_path("profiles", create(:profile)) }

      it "points the field label at the foreign key select" do
        expect(document.at_css("label[for=record_user_id]").text.squish).to eq("User")
      end
    end

    context "with a polymorphic belongs_to" do
      let(:path) { iron_admin.edit_resource_path("notes", Note.create!(title: "Note", notable: create(:user))) }

      it "points the field label at the type select" do
        expect(document.at_css("label[for=record_notable_type]").text.squish).to eq("Notable")
      end

      it "names the record select" do
        expect(document.at_css("select#record_notable_id")["aria-label"]).to eq("Notable record")
      end
    end

    context "with radio buttons" do
      let(:path) { iron_admin.new_resource_path("widgets") }

      it "labels the radio group with the field name" do
        group = document.at_css("[role=radiogroup]")
        expect(document.at_css("##{group["aria-labelledby"]}").text.squish).to eq("Status")
      end
    end

    context "with a boolean group" do
      let(:path) { iron_admin.new_resource_path("widgets") }

      it "labels the checkbox group with the field name" do
        group = document.at_css("[role=group]")
        expect(document.at_css("##{group["aria-labelledby"]}").text.squish).to eq("Permissions")
      end
    end

    context "with has_many checkboxes" do
      let(:path) { iron_admin.new_resource_path("posts") }

      before { create_list(:tag, 2) }

      it "labels the checkbox group with the association name" do
        group = document.at_css("[role=group]")
        expect(document.at_css("##{group["aria-labelledby"]}").text.squish).to eq("Tags")
      end

      it "gives each checkbox its own id" do
        expect(document.css("input[name='record[tag_ids][]']").pluck("id").uniq.size).to eq(2)
      end
    end

    context "with a tags field" do
      let(:path) { iron_admin.new_resource_path("posts") }

      it "points the field label at the text input" do
        expect(document.at_css("input#record_category_tags")).to have_attribute("data-tag-input")
      end
    end
  end

  describe "a polymorphic belongs_to with inferred types" do
    before do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::AutoNoteResource)
    end

    describe "on the new form" do
      let(:path) { iron_admin.new_resource_path("notes") }

      it_behaves_like "a page whose form controls are all named"
    end

    describe "on the edit form" do
      let(:path) { iron_admin.edit_resource_path("notes", Note.create!(title: "Note", notable: create(:license))) }

      it_behaves_like "a page whose form controls are all named"
    end
  end

  describe "a belongs_to autocomplete" do
    let(:target_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "AccessibleAutocompleteUserResource"
        def self.resource_name = "accessible_autocomplete_users"
      end
    end

    let(:license_resource) do
      target = target_resource

      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name = "AccessibleAutocompleteLicenseResource"
        def self.resource_name = "accessible_autocomplete_licenses"

        belongs_to :user, display: :email, autocomplete: true, resource: target
        form_fields :license_key, :user
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(target_resource)
      IronAdmin::ResourceRegistry.register(license_resource)
    end

    describe "on the new form" do
      let(:path) { iron_admin.new_resource_path("accessible_autocomplete_licenses") }

      it_behaves_like "a page whose form controls are all named"
    end

    describe "on the edit form" do
      let(:path) { iron_admin.edit_resource_path("accessible_autocomplete_licenses", create(:license)) }

      it_behaves_like "a page whose form controls are all named"

      it "points the field label at the combobox" do
        expect(document.at_css("input#record_user_id")["role"]).to eq("combobox")
      end
    end
  end

  describe "nested rows and the Add row template" do
    let(:nested_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "AccessibleNestedUserResource"
        def self.resource_name = "accessible_nested_users"

        field :role, type: :select, choices: %w[admin member]
        has_many :licenses, nested: true, allow_destroy: true
      end
    end

    before { IronAdmin::ResourceRegistry.register(nested_resource) }

    describe "on the new form" do
      let(:path) { iron_admin.new_resource_path("accessible_nested_users") }

      it_behaves_like "a page whose form controls are all named"
    end

    describe "on the edit form" do
      let(:path) { iron_admin.edit_resource_path("accessible_nested_users", create(:license).user) }

      it_behaves_like "a page whose form controls are all named"

      it "points each row label at its control" do
        expect(document.at_css("label[for=record_licenses_attributes_0_license_key]").text.squish).to eq("License key")
      end

      it "points each template label at its control" do
        expect(document.at_css("template label[for=record_licenses_attributes_NEW_RECORD_INDEX_license_key]")).to be_present
      end
    end
  end

  describe "the index page" do
    let(:filtered_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "AccessibleFilteredUserResource"
        def self.resource_name = "accessible_filtered_users"

        searchable :name
        filter :role, type: :select
        filter :active, type: :boolean
        filter :created_at, type: :date_range
        filter :name, type: :string
        filter :id, type: :number
        bulk_action(:archive) { |_users| true }
      end
    end

    let(:path) { iron_admin.resources_path("accessible_filtered_users") }

    before do
      IronAdmin::ResourceRegistry.register(filtered_resource)
      create(:user, role: "admin")
    end

    it_behaves_like "a page whose form controls are all named"

    it "names the search input after the resource" do
      expect(document.at_css("input#q")["aria-label"]).to eq("Search Users")
    end

    it "points each filter label at its control" do
      expect(document.css("details label[for]").pluck("for"))
        .to eq(%w[filters_email_value filters_role filters_active filters_created_at_from filters_name_value filters_id_value])
    end

    it "names the operator selects after their filter" do
      expect(document.css("select[name$='[op]']").pluck("aria-label")).to eq(["Email operator", "Name operator", "Id operator"])
    end

    it "names the date range inputs after their filter" do
      expect(document.css("input[type=date]").pluck("aria-label")).to eq(["Created at from", "Created at to"])
    end

    it "names the upper value of a between filter" do
      expect(document.at_css("input[name='filters[id][value_2]']")["aria-label"]).to eq("Id upper value")
    end

    it "names the bulk-select header checkbox" do
      expect(document.at_css("input[data-cp-bulk-select-target=selectAll]")["aria-label"]).to eq("Select all")
    end

    it "names each row checkbox after its record" do
      expect(document.at_css("input[name='ids[]']")["aria-label"]).to eq("Select #{User.first.name}")
    end
  end

  describe "the import pages" do
    let(:import_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "AccessibleImportUserResource"
        def self.resource_name = "accessible_import_users"

        imports :csv
        import_fields :name, :email
      end
    end

    before { IronAdmin::ResourceRegistry.register(import_resource) }

    describe "the upload form" do
      let(:path) { iron_admin.resource_import_path("accessible_import_users") }

      it_behaves_like "a page whose form controls are all named"
    end

    describe "the preview" do
      let(:csv) { Rack::Test::UploadedFile.new(StringIO.new("Name,Email\nJane,jane@example.com\n"), "text/csv", true, original_filename: "users.csv") }

      it "names every control and points every label at one" do
        post iron_admin.resource_import_preview_path("accessible_import_users"), params: { file: csv }

        expect(form_accessibility_problems(response.body)).to be_empty
      end
    end
  end

  describe "the audit log filters" do
    let(:path) { iron_admin.audit_path }

    before do
      IronAdmin.configure { |config| config.audit_enabled = true }
      IronAdmin::AuditLog.log(Struct.new(:user, :action, :resource, :record_id, :changes, :ip_address)
        .new(nil, :create, "IronAdmin::Resources::UserResource", 1, {}, "127.0.0.1"))
    end

    it_behaves_like "a page whose form controls are all named"
  end
end
