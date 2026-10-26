# frozen_string_literal: true

require "rails_helper"

# The dummy app overrides `layouts/iron_admin/application` with a bare ERB
# layout, so the other request specs never render the engine's real layout
# (its importmap tags, stylesheets and shell). This spec puts the engine's
# own views first so the real layout renders.
RSpec.describe "Engine layout", type: :request do
  around do |example|
    original_view_paths = IronAdmin::ApplicationController.view_paths
    IronAdmin::ApplicationController.prepend_view_path(IronAdmin::Engine.root.join("app/views"))
    example.run
  ensure
    IronAdmin::ApplicationController.view_paths = original_view_paths
  end

  describe "GET /:resource_name" do
    subject(:body) do
      get iron_admin.resources_path("users"), as: :html
      response.body
    end

    it "pins every IronAdmin Stimulus controller in the rendered import map" do
      pins = IronAdmin::Engine.root.glob("app/javascript/iron_admin/controllers/*_controller.js").map do |file|
        %("iron_admin/controllers/#{file.basename(".js")}")
      end

      expect(pins).to all(satisfy { |pin| body.include?(pin) })
    end

    it "imports the IronAdmin entry point" do
      expect(body).to include(%(import "iron_admin"))
    end

    it "renders the shell sidebar" do
      expect(body).to match(/id=["']cp-sidebar-panel["']/)
    end

    it "renders the page content in the main landmark" do
      expect(Nokogiri::HTML(body).at_css("main#main-content h1")).to be_present
    end
  end

  describe "GET /search" do
    subject(:search_input) do
      get iron_admin.search_path(q: "Rails"), as: :html
      response.parsed_body.at_css("header input[name='q']")
    end

    it "keeps the query in the navbar search box" do
      expect(search_input[:value]).to eq("Rails")
    end
  end
end
