# frozen_string_literal: true

require "rails_helper"

# Heading levels and text colors that axe-core flagged on default-theme pages.
# Contrast: zinc-400 on zinc-50 is 2.5:1 and zinc-500 on zinc-100 is 4.4:1
# (below WCAG AA); zinc-500 on zinc-50 is 4.6:1 and zinc-700 on zinc-100 is 9.5:1.
RSpec.describe "Default theme accessibility", type: :request do
  let(:document) { response.parsed_body }
  let(:import_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name = "ContrastImportUserResource"
      def self.resource_name = "contrast_import_users"

      imports :csv
      import_fields :name, :email
    end
  end

  describe "heading order" do
    context "with a dashboard that has every built-in widget" do
      before do
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
        create(:post)
        IronAdmin.dashboard_class = Class.new(IronAdmin::Dashboard) do
          metric(:total_posts) { Post.count }
          chart(:posts_by_day, type: :bar) { { "Mon" => 1 } }
          progress(:goal, max: 10) { 4 }
          recent :posts
        end
        get iron_admin.root_path, as: :html
      end

      it "titles the widgets one level below the page title" do
        expect(heading_order_problems(document)).to be_empty
      end
    end

    context "with an edit page that has a nested form" do
      let(:nested_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name = "HeadingOrderUserResource"
          def self.resource_name = "heading_order_users"

          has_many :licenses, nested: true
        end
      end

      before do
        IronAdmin::ResourceRegistry.register(nested_resource)
        get iron_admin.edit_resource_path("heading_order_users", create(:user)), as: :html
      end

      it "titles the nested section one level below the page title" do
        expect(heading_order_problems(document)).to be_empty
      end
    end
  end

  describe "record id next to the page title" do
    let(:user) { create(:user) }
    let(:id_classes) { document.at_css("h1 span")[:class].split }

    {
      "GET /:resource_name/:id" => ->(user) { iron_admin.resource_path("users", user) },
      "GET /:resource_name/:id/edit" => ->(user) { iron_admin.edit_resource_path("users", user) },
    }.each do |page, path|
      context "with #{page}" do
        before { get instance_exec(user, &path), as: :html }

        it "uses the theme's muted text color, which keeps 4.5:1 on the page background" do
          expect(id_classes).to include("text-zinc-500")
        end

        it "does not use zinc-400, which is 2.5:1 on the page background" do
          expect(id_classes).not_to include("text-zinc-400")
        end
      end
    end
  end

  describe "GET /:resource_name/import" do
    let(:column_chips) { document.css("form .flex-wrap > span") }

    before do
      IronAdmin::ResourceRegistry.register(import_resource)
      get iron_admin.resource_import_path("contrast_import_users"), as: :html
    end

    it "writes the column chips in zinc-700, which keeps 9.5:1 on their zinc-100 background" do
      expect(column_chips.map { |chip| chip[:class].split }).to all(include("text-zinc-700"))
    end

    it "lists every import column" do
      expect(column_chips.map { |chip| chip.text.strip }).to eq(%w[Name Email])
    end
  end

  describe "POST /:resource_name/import/preview" do
    let(:column_chips) { document.css(".flex-wrap > span") }

    before do
      IronAdmin::ResourceRegistry.register(import_resource)
      file = Rack::Test::UploadedFile.new(StringIO.new("Name,Email\nJane,jane@example.com\n"), "text/csv", true,
                                          original_filename: "users.csv")
      post iron_admin.resource_import_preview_path("contrast_import_users"), params: { file: file }
    end

    it "writes the mapping chips in zinc-700, which keeps 9.5:1 on their zinc-100 background" do
      expect(column_chips.map { |chip| chip[:class].split }).to all(include("text-zinc-700"))
    end

    it "lists every mapped column" do
      expect(column_chips.map { |chip| chip.text.squish }).to eq(["Name -> Name", "Email -> Email"])
    end
  end

  describe "pagination" do
    let(:disabled_links) { document.css("nav[aria-label='Pagination'] .cursor-not-allowed") }

    before do
      IronAdmin.configuration.per_page = 1
      create_list(:user, 2)
      get iron_admin.resources_path("users", page: page), as: :html
    end

    context "when on the first page" do
      let(:page) { 1 }

      it "renders the unavailable Previous link" do
        expect(disabled_links.map { |link| link.text.strip }).to eq(["Previous"])
      end

      it "exposes it as a disabled link, so its faded text needs no 4.5:1 contrast" do
        expect(disabled_links.map { |link| [link[:role], link["aria-disabled"]] }).to eq([%w[link true]])
      end
    end

    context "when on the last page" do
      let(:page) { 2 }

      it "exposes the unavailable Next item as a disabled link" do
        expect(disabled_links.map { |link| [link.text.strip, link[:role], link["aria-disabled"]] })
          .to eq([%w[Next link true]])
      end
    end
  end
end
