# frozen_string_literal: true

require "rails_helper"

# Define a test tool for specs
class SampleTool < IronAdmin::Tool
  menu icon: "wrench", label: "Sample Tool", priority: 1, group: "Utilities"

  def ping
    # no-op action for testing
  end
end

RSpec.describe "Custom tools", type: :request do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ToolRegistry.register(SampleTool)
  end

  describe "GET /tools/:tool_name" do
    it "renders the tool page" do
      get tool_path("sample")
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for unknown tool" do
      get tool_path("nonexistent")
      expect(response).to have_http_status(:not_found)
    end

    it "includes tool label in page" do
      get tool_path("sample")
      expect(response.body).to include("Sample Tool")
    end
  end

  describe "POST /tools/:tool_name/:action_name" do
    it "executes a valid action and redirects" do
      post tool_action_path("sample", "ping")
      expect(response).to redirect_to(tool_path("sample"))
    end

    it "returns 404 for unknown action" do
      post tool_action_path("sample", "nonexistent")
      expect(response).to have_http_status(:not_found)
    end

    it "does not call inherited methods" do
      post tool_action_path("sample", "exit")
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for unknown tool" do
      post tool_action_path("nonexistent", "ping")
      expect(response).to have_http_status(:not_found)
    end
  end
end
