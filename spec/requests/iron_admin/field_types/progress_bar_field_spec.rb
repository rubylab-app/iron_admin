# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Progress bar field type", type: :request do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::WidgetResource)
  end

  describe "GET /:resource_name/:id (show)" do
    it "renders progress bar with percentage" do
      widget = create(:widget, completion: 75)
      get iron_admin.resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("75%")
      expect(response.body).to include("bg-green-500")
    end

    it "rounds the bar with the theme's control_radius" do
      widget = create(:widget, completion: 75)
      get iron_admin.resource_path("widgets", widget), as: :html

      bar = response.parsed_body.at_css(".bg-green-500")
      expect(bar[:class].split).to include(IronAdmin.current_theme.control_radius)
    end

    it "handles zero completion" do
      widget = create(:widget, completion: 0)
      get iron_admin.resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("0%")
    end

    it "handles nil value gracefully" do
      widget = create(:widget, completion: nil)
      get iron_admin.resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /:resource_name/new" do
    it "renders number input for progress bar" do
      get iron_admin.new_resource_path("widgets"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('type="number"')
      expect(response.body).to include("completion")
    end
  end

  describe "POST /:resource_name (create)" do
    it "persists the completion value" do
      post iron_admin.resources_path("widgets"),
           params: { record: { name: "Progress Widget", completion: "80" } },
           as: :html

      expect(Widget.last.completion).to eq(80)
    end
  end

  describe "PATCH /:resource_name/:id (update)" do
    it "updates the completion value" do
      widget = create(:widget, completion: 50)

      patch iron_admin.resource_path("widgets", widget),
            params: { record: { name: widget.name, completion: "90" } },
            as: :html

      expect(widget.reload.completion).to eq(90)
    end
  end
end
