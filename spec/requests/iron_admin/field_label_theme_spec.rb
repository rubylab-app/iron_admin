# frozen_string_literal: true

require "rails_helper"

# Field labels take their case and letter spacing from the theme's field_label_transform.
RSpec.describe "Field label theme", type: :request do
  let(:document) { response.parsed_body }
  let(:transform) { %w[uppercase tracking-wider] }

  def classes_at(selector)
    document.at_css(selector)[:class].split
  end

  before do
    IronAdmin.configuration.register_theme(:loud) { |t| t.field_label_transform = "uppercase tracking-wider" }
    cookies["iron_admin_theme"] = "loud"
  end

  describe "GET /:resource_name/new" do
    before { get iron_admin.new_resource_path("users"), as: :html }

    it "transforms the label of each field" do
      expect(classes_at("label[for=record_name]")).to include(*transform)
    end
  end

  describe "GET /:resource_name/new with radio fields" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::WidgetResource)
      get iron_admin.new_resource_path("widgets"), as: :html
    end

    it "transforms the label of the radio group" do
      expect(classes_at("#record_status_label")).to include(*transform)
    end
  end

  describe "GET /:resource_name/new with a has-and-belongs-to-many association" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::TagResource)
      get iron_admin.new_resource_path("posts"), as: :html
    end

    it "transforms the label of the association's checkboxes" do
      expect(classes_at("#record_tag_ids_label")).to include(*transform)
    end
  end

  describe "GET /:resource_name/:id/edit with nested records" do
    let(:nested_user_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "LabelNestedUserResource"
        end

        def self.resource_name
          "label_nested_users"
        end

        has_many :licenses, nested: true
      end
    end
    let(:user) { create(:user) }

    before do
      IronAdmin::ResourceRegistry.register(nested_user_resource)
      create(:license, user: user)
      get iron_admin.edit_resource_path("label_nested_users", user), as: :html
    end

    it "transforms the labels of the nested fields" do
      expect(classes_at("[data-cp-nested-form-target=row] label")).to include(*transform)
    end
  end

  describe "GET /:resource_name/:id" do
    let(:user) { create(:user) }

    before do
      create(:profile, user: user)
      get iron_admin.resource_path("users", user), as: :html
    end

    it "transforms the field names of the record" do
      expect(classes_at("dl dt")).to include(*transform)
    end

    it "transforms the field names of a has-one record" do
      expect(document.css("dl").last.at_css("dt")[:class].split).to include(*transform)
    end
  end

  describe "GET /:resource_name/import" do
    let(:import_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "LabelImportUserResource"
        end

        def self.resource_name
          "label_import_users"
        end

        imports :csv
        import_fields :name, :email
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(import_resource)
      get iron_admin.resource_import_path("label_import_users"), as: :html
    end

    it "transforms the file label" do
      expect(classes_at("label[for=file]")).to include(*transform)
    end

    it "transforms the format label" do
      expect(classes_at("label[for=import_format]")).to include(*transform)
    end

    it "transforms the label of the field list" do
      expect(document.css("form p").map { |label| label[:class].split }).to include(include(*transform))
    end
  end

  describe "GET /:resource_name/:id/actions/:action_name" do
    let(:form_action_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "LabelActionResource"
        end

        def self.resource_name
          "label_action_licenses"
        end

        action :revoke_with_reason, form_fields: [action_field(:reason, type: :textarea)] do |license, params|
          license.update!(license_type: params[:reason])
        end
      end
    end
    let(:license) { create(:license) }

    before do
      IronAdmin::ResourceRegistry.register(form_action_resource)
      get iron_admin.resource_action_form_path("label_action_licenses", license, "revoke_with_reason"), as: :html
    end

    it "transforms the label of each action field" do
      expect(classes_at("label[for$=_reason]")).to include(*transform)
    end
  end

  context "with the Neutral theme" do
    before do
      cookies.delete("iron_admin_theme")
      get iron_admin.new_resource_path("users"), as: :html
    end

    it "keeps the labels as written" do
      expect(classes_at("label[for=record_name]")).not_to include("uppercase")
    end
  end
end
