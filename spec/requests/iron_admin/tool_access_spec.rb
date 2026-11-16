# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tool access", type: :request do
  let(:calls) { [] }
  let(:tool_class) do
    recorded = calls
    Class.new(IronAdmin::Tool) do
      def self.name = "PurgeTool"

      tool_access ->(user) { user&.role == "admin" }

      tool_action :purge_cache
      tool_action :purge_key, form_fields: [{ name: :key, type: :text }]

      define_method(:purge_cache) { recorded << :purge_cache }
      define_method(:purge_key) { recorded << :purge_key }
    end
  end

  def sign_in_as(role)
    user = Struct.new(:role).new(role)
    IronAdmin.configure { |config| config.current_user { user } }
  end

  before { IronAdmin::ToolRegistry.register(tool_class) }

  context "when tool_access denies the user" do
    before { sign_in_as("reader") }

    it "forbids the tool page" do
      get tool_path("purge")

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids an action declared without a condition, and does not run it" do
      post tool_action_path("purge", "purge_cache"), as: :html

      expect(response).to have_http_status(:forbidden)
      expect(calls).to be_empty
    end

    it "forbids an action form" do
      get tool_action_form_path("purge", "purge_key")

      expect(response).to have_http_status(:forbidden)
    end
  end

  context "when tool_access allows the user" do
    before { sign_in_as("admin") }

    it "renders the tool page" do
      get tool_path("purge")

      expect(response).to have_http_status(:ok)
    end

    it "runs the action" do
      post tool_action_path("purge", "purge_cache"), as: :html

      expect(calls).to eq([:purge_cache])
    end
  end

  context "with a tool that declares no actions" do
    let(:legacy_tool) do
      recorded = calls
      Class.new(IronAdmin::Tool) do
        def self.name = "LegacyPurgeTool"

        tool_access { |user| user&.role == "admin" }

        define_method(:ping) { recorded << :ping }
      end
    end

    before do
      allow(IronAdmin.deprecator).to receive(:warn)
      IronAdmin::ToolRegistry.register(legacy_tool)
      sign_in_as("reader")
    end

    it "forbids a legacy dispatch, and does not run the method" do
      post tool_action_path("legacy_purge", "ping"), as: :html

      expect(response).to have_http_status(:forbidden)
      expect(calls).to be_empty
    end
  end

  context "with a tool without tool_access" do
    let(:open_tool) do
      Class.new(IronAdmin::Tool) do
        def self.name = "OpenReportTool"
      end
    end

    before { IronAdmin::ToolRegistry.register(open_tool) }

    it "renders the page while default_policy is :allow" do
      get tool_path("open_report")

      expect(response).to have_http_status(:ok)
    end

    it "forbids the page when default_policy is :deny" do
      IronAdmin.configuration.default_policy = :deny

      get tool_path("open_report")

      expect(response).to have_http_status(:forbidden)
    end
  end
end
