# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Form field order", type: :request do
  # The users table stores name, email, role, active, so this declaration is out of column order.
  let(:ordered_user_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name = "OrderedFormUserResource"
      def self.resource_name = "ordered_form_users"

      form_fields :role, :licenses, :email, :name, :active
    end
  end

  let(:declared_label_targets) { %w[record_role record_email record_name record_active] }
  let(:rendered_label_targets) { response.parsed_body.css("form label").pluck("for") }

  before { IronAdmin::ResourceRegistry.register(ordered_user_resource) }

  describe "GET /:resource_name/new" do
    it "renders the inputs in the declared form_fields order" do
      get iron_admin.new_resource_path("ordered_form_users"), as: :html

      expect(rendered_label_targets).to eq(declared_label_targets)
    end
  end

  describe "GET /:resource_name/:id/edit" do
    it "renders the inputs in the declared form_fields order" do
      get iron_admin.edit_resource_path("ordered_form_users", create(:user)), as: :html

      expect(rendered_label_targets).to eq(declared_label_targets)
    end
  end

  describe "POST /:resource_name" do
    context "with valid params" do
      it "saves every declared field" do
        post iron_admin.resources_path("ordered_form_users"),
             params: { record: { role: "admin", email: "ordered@example.com", name: "Ordered", active: "0" } },
             as: :html

        expect(User.last).to have_attributes(role: "admin", email: "ordered@example.com", name: "Ordered", active: false)
      end
    end

    context "with invalid params" do
      it "re-renders the inputs in the declared form_fields order" do
        post iron_admin.resources_path("ordered_form_users"),
             params: { record: { role: "admin", email: "", name: "" } },
             as: :html

        expect(rendered_label_targets).to eq(declared_label_targets)
      end
    end
  end

  describe "PATCH /:resource_name/:id" do
    context "with a readonly field in the declaration" do
      let(:ordered_user_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name = "ReadonlyOrderedFormUserResource"
          def self.resource_name = "ordered_form_users"

          field :role, readonly: true
          form_fields :role, :email, :name
        end
      end

      it "does not persist the readonly field" do
        user = create(:user, role: "member")

        patch iron_admin.resource_path("ordered_form_users", user),
              params: { record: { role: "admin", email: user.email, name: "Renamed" } },
              as: :html

        expect(user.reload).to have_attributes(role: "member", name: "Renamed")
      end
    end

    context "with a file field declared before the columns" do
      let(:ordered_document_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = Document

          def self.name = "OrderedFormDocumentResource"
          def self.resource_name = "ordered_form_documents"

          field :cover_image, type: :file
          form_fields :cover_image, :title
        end
      end

      before { IronAdmin::ResourceRegistry.register(ordered_document_resource) }

      it "purges the attachment when its remove box is checked" do
        document = create(:document)
        document.cover_image.attach(io: StringIO.new("image"), filename: "photo.jpg", content_type: "image/jpeg")

        patch iron_admin.resource_path("ordered_form_documents", document),
              params: { record: { title: document.title, cover_image_purge: "1" } },
              as: :html

        expect(document.reload.cover_image).not_to be_attached
      end
    end
  end
end
