# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Plugin theme", type: :request do
  # The dummy app overrides the engine layout with a bare page, which has no
  # switcher. Prepend the engine's views, as the engine layout spec does.
  around do |example|
    original_view_paths = IronAdmin::ApplicationController.view_paths
    IronAdmin::ApplicationController.prepend_view_path(IronAdmin::Engine.root.join("app/views"))
    example.run
  ensure
    IronAdmin::ApplicationController.view_paths = original_view_paths
  end

  let(:new_button_classes) do
    response.parsed_body.at_css("a[href='#{iron_admin.new_resource_path("users")}']")[:class].split
  end

  before { IronAdmin.register_plugin(IronAdmin::Theme::HighContrast) }

  describe "theme switcher" do
    before { get iron_admin.resources_path("users"), as: :html }

    it "lists the plugin theme" do
      button = response.parsed_body.at_css("header details form button[value='high_contrast']")

      expect(button.text.squish).to eq("High Contrast")
    end
  end

  describe "POST /theme" do
    before { post iron_admin.theme_path, params: { theme: "high_contrast", return_to: "/admin/users" } }

    it "stores the plugin theme in the cookie" do
      expect(cookies["iron_admin_theme"]).to eq("high_contrast")
    end
  end

  context "with the theme cookie set to the plugin theme" do
    before do
      cookies["iron_admin_theme"] = "high_contrast"
      get iron_admin.resources_path("users"), as: :html
    end

    it "renders the page with that theme" do
      expect(new_button_classes).to include("plugin-theme-primary")
    end
  end

  context "when config.theme_resolver names the plugin theme" do
    before do
      IronAdmin.configuration.theme_resolver { |_request| :high_contrast }
      get iron_admin.resources_path("users"), as: :html
    end

    it "renders the page with that theme" do
      expect(new_button_classes).to include("plugin-theme-primary")
    end
  end
end
