# frozen_string_literal: true

require "rails_helper"

# Every admin page sits in the same padded container and titles itself with the
# theme's page title, so the title does not move when navigating between pages.
RSpec.describe "Admin page layout", type: :request do
  let(:document) { response.parsed_body }
  let(:main) { document.at_css("#main-content") }
  let(:container_classes) { main.element_children.last[:class].to_s.split }
  let(:title_classes) { main.at_css("h1")[:class].to_s.split }
  let(:neutral) { IronAdmin.configuration.theme }
  let(:user) { create(:user) }

  # The dummy app overrides the engine layout (see layout_spec.rb).
  around do |example|
    original_view_paths = IronAdmin::ApplicationController.view_paths
    IronAdmin::ApplicationController.prepend_view_path(IronAdmin::Engine.root.join("app/views"))
    example.run
  ensure
    IronAdmin::ApplicationController.view_paths = original_view_paths
  end

  before { IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource) }

  {
    "the dashboard" => -> { iron_admin.root_path },
    "an index page" => -> { iron_admin.resources_path("users") },
    "a show page" => -> { iron_admin.resource_path("users", user) },
    "a new page" => -> { iron_admin.new_resource_path("users") },
    "an edit page" => -> { iron_admin.edit_resource_path("users", user) },
    "the search page" => -> { iron_admin.search_path(q: "Ada") },
    "an error page" => -> { iron_admin.resource_path("users", 999_999) },
  }.each do |page, path|
    describe page do
      before { get instance_exec(&path), as: :html }

      it "pads the page with the page padding" do
        expect(container_classes).to include("px-4", "sm:px-6", "lg:px-8", "py-6")
      end

      it "drops the old all-around padding" do
        expect(container_classes & %w[p-4 sm:p-6 lg:p-8]).to be_empty
      end

      it "titles the page with the theme's page title" do
        expect(title_classes).to include(*neutral.page_title.split)
      end
    end
  end

  describe "flash messages" do
    subject(:flash_classes) { main.element_children.first[:class].to_s.split }

    before do
      post iron_admin.resources_path("users"), params: { record: { name: "Ada", email: "ada@example.com" } }
      follow_redirect!
    end

    it "start at the top padding of the page" do
      expect(flash_classes).to include("pt-6")
    end

    it "drop the old responsive top padding" do
      expect(flash_classes & %w[pt-4 sm:pt-6 lg:pt-8]).to be_empty
    end
  end
end
