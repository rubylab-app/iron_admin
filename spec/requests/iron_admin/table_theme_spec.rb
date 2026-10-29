# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Table theme", type: :request do
  let(:document) { response.parsed_body }

  def classes_at(selector)
    document.at_css(selector)[:class].split
  end

  context "with a theme that hovers the sticky actions cell" do
    before do
      IronAdmin.configuration.register_theme(:night) do |t|
        t.table_row_hover = "hover:bg-zinc-800"
        t.table_sticky_row_hover = "group-hover/row:bg-zinc-800"
      end
      cookies["iron_admin_theme"] = "night"
      create(:user)
      get iron_admin.resources_path("users"), as: :html
    end

    it "names each body row as a group" do
      expect(classes_at("table tbody tr")).to include("group/row", "hover:bg-zinc-800")
    end

    it "gives the sticky actions cell that theme's table_sticky_row_hover" do
      expect(classes_at("table tbody tr td.sticky")).to include("group-hover/row:bg-zinc-800")
    end
  end

  context "with a theme that rules table heads apart" do
    before do
      IronAdmin.configuration.register_theme(:print) do |t|
        t.table_border = "divide-stone-300"
        t.table_head_border = "divide-stone-900"
      end
      cookies["iron_admin_theme"] = "print"
    end

    describe "GET /:resource_name" do
      before do
        create(:user)
        get iron_admin.resources_path("users"), as: :html
      end

      it "draws the line under the head in table_head_border" do
        expect(classes_at("table")).to include("divide-stone-900")
      end

      it "draws the lines between rows in table_border" do
        expect(classes_at("table tbody")).to include("divide-stone-300")
      end
    end

    describe "POST /:resource_name/import/preview" do
      let(:import_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "TableImportUserResource"
          end

          def self.resource_name
            "table_import_users"
          end

          imports :csv
          import_fields :name, :email
        end
      end

      before do
        IronAdmin::ResourceRegistry.register(import_resource)
        file = Rack::Test::UploadedFile.new(StringIO.new("Name,Email\nJane,jane@example.com\n"), "text/csv", true,
                                            original_filename: "users.csv")
        post iron_admin.resource_import_preview_path("table_import_users"), params: { file: file }
      end

      it "draws the line under the head in table_head_border" do
        expect(classes_at("table")).to include("divide-stone-900")
      end

      it "draws the lines between rows in table_border" do
        expect(classes_at("table tbody")).to include("divide-stone-300")
      end
    end
  end
end
