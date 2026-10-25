# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Radio field type", type: :request do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::WidgetResource)
  end

  describe "GET /:resource_name/:id (show)" do
    it "displays the humanized radio value" do
      widget = create(:widget, status: "active")
      get iron_admin.resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Active")
    end

    it "handles nil value gracefully" do
      widget = create(:widget, status: nil)
      get iron_admin.resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /:resource_name/new" do
    it "renders radio buttons for choices" do
      get iron_admin.new_resource_path("widgets"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("input[type=radio]")).not_to be_empty
      expect(response.body).to include("Active")
      expect(response.body).to include("Inactive")
      expect(response.body).to include("Draft")
    end
  end

  describe "GET /:resource_name/:id/edit" do
    it "pre-selects current value" do
      widget = create(:widget, status: "inactive")
      get iron_admin.edit_resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("input[type=radio]")).not_to be_empty
      expect(response.body).to include("checked")
    end
  end

  describe "POST /:resource_name (create)" do
    it "persists the selected radio value" do
      post iron_admin.resources_path("widgets"),
           params: { record: { name: "Radio Widget", status: "draft" } },
           as: :html

      expect(Widget.last.status).to eq("draft")
    end
  end

  describe "PATCH /:resource_name/:id (update)" do
    it "updates the radio value" do
      widget = create(:widget, status: "active")

      patch iron_admin.resource_path("widgets", widget),
            params: { record: { name: widget.name, status: "inactive" } },
            as: :html

      expect(widget.reload.status).to eq("inactive")
    end
  end
end
