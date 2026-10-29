# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Code field type", type: :request do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::WidgetResource)
  end

  describe "GET /:resource_name/:id (show)" do
    it "renders code in pre/code block with language class" do
      widget = create(:widget, source_code: "def hello; end")
      get iron_admin.resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("def hello; end")
      expect(response.body).to include("font-mono")
      expect(response.body).to include("bg-zinc-950")
    end

    it "handles nil code gracefully" do
      widget = create(:widget, source_code: nil)
      get iron_admin.resource_path("widgets", widget), as: :html

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /:resource_name/new" do
    it "renders monospace textarea for code field" do
      get iron_admin.new_resource_path("widgets"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("font-mono")
      expect(response.body).to include("source_code")
    end
  end

  describe "POST /:resource_name (create)" do
    it "persists code content" do
      post iron_admin.resources_path("widgets"),
           params: { record: { name: "Code Widget", source_code: "class Foo; end" } },
           as: :html

      expect(Widget.last.source_code).to eq("class Foo; end")
    end
  end

  describe "PATCH /:resource_name/:id (update)" do
    it "updates code content" do
      widget = create(:widget, source_code: "old code")

      patch iron_admin.resource_path("widgets", widget),
            params: { record: { name: widget.name, source_code: "new code" } },
            as: :html

      expect(widget.reload.source_code).to eq("new code")
    end
  end
end
