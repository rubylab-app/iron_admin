# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Boolean group field type", type: :request do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::WidgetResource)
  end

  describe "GET /:resource_name/:id (show)" do
    it "displays selected values as pill badges" do
      widget = create(:widget, permissions: "read,write")
      get iron_admin.resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Read")
      expect(response.body).to include("Write")
      expect(response.body).to include("bg-indigo-50")
    end

    it "handles empty permissions gracefully" do
      widget = create(:widget, permissions: "")
      get iron_admin.resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
    end

    it "handles nil permissions gracefully" do
      widget = create(:widget, permissions: nil)
      get iron_admin.resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /:resource_name (index)" do
    it "shows compact summary on index" do
      create(:widget, permissions: "read,write,delete")
      get iron_admin.resources_path("widgets"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("3 selected")
    end
  end

  describe "GET /:resource_name/new" do
    it "renders checkboxes for each choice" do
      get iron_admin.new_resource_path("widgets"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("input[type=checkbox]")).not_to be_empty
      expect(response.body).to include("Read")
      expect(response.body).to include("Write")
      expect(response.body).to include("Delete")
      expect(response.body).to include("Admin")
    end
  end

  describe "GET /:resource_name/:id/edit" do
    it "pre-checks selected values" do
      widget = create(:widget, permissions: "read,write")
      get iron_admin.edit_resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.css("input[type=checkbox]")).not_to be_empty
      expect(response.body).to include("checked")
    end
  end

  describe "POST /:resource_name (create)" do
    it "persists selected permissions as CSV" do
      post iron_admin.resources_path("widgets"),
           params: { record: { name: "Group Widget", permissions: "read,write" } },
           as: :html

      expect(Widget.last.permissions).to eq("read,write")
    end
  end

  describe "PATCH /:resource_name/:id (update)" do
    it "updates permissions" do
      widget = create(:widget, permissions: "read")

      patch iron_admin.resource_path("widgets", widget),
            params: { record: { name: widget.name, permissions: "read,write,admin" } },
            as: :html

      expect(widget.reload.permissions).to eq("read,write,admin")
    end
  end
end
