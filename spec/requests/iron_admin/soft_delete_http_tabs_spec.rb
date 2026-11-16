# frozen_string_literal: true

require "rails_helper"

RSpec.describe "HTTP soft-delete scope tabs", type: :request do
  let(:http_resource) do
    Class.new(IronAdmin::Resource) do
      self.adapter_class = :http

      def self.name = "IronAdmin::Resources::RemoteWidgetResource"
      def self.resource_name = "remote_widgets"

      index_fields :name
    end
  end

  before do
    IronAdmin.configuration.http_base_url = "https://api.example.com/v1"
    stub_request(:get, %r{https://api\.example\.com/v1/remote_widgets}).to_return(
      status: 200,
      body: [{ id: 1, name: "Widget", deleted_at: nil }].to_json,
      headers: { "Content-Type" => "application/json" }
    )
    IronAdmin::ResourceRegistry.register(http_resource)
  end

  it "answers 200 for the with_deleted scope" do
    get iron_admin.resources_path("remote_widgets", scope: "with_deleted"), as: :html

    expect(response).to have_http_status(:ok)
  end
end
