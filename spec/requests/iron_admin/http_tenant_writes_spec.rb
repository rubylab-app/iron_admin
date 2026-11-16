# frozen_string_literal: true

require "rails_helper"

RSpec.describe "HTTP tenant writes", type: :request do
  let(:http_resource) do
    Class.new(IronAdmin::Resource) do
      self.adapter_class = :http

      def self.name = "IronAdmin::Resources::RemoteItemResource"
      def self.resource_name = "remote_items"

      index_fields :name
      form_fields :name, :owner_id
    end
  end

  before do
    IronAdmin.configuration.http_base_url = "https://api.example.com/v1"
    stub_remote_items
    IronAdmin::ResourceRegistry.register(http_resource)
  end

  context "when the tenant scope is an IN list" do
    before { set_tenant_scope { |scope| scope.where(owner_id: [1, 2]) } }

    it "rejects the create and does not post" do
      post iron_admin.resources_path("remote_items"),
           params: { record: { name: "Widget", owner_id: 1 } },
           as: :html

      expect(response).to have_http_status(422)
      expect(a_request(:post, %r{https://api\.example\.com/v1/remote_items})).not_to have_been_made
    end
  end

  context "when the tenant scope is an equality" do
    before { set_tenant_scope { |scope| scope.where(owner_id: 1) } }

    it "posts the tenant owner_id" do
      post iron_admin.resources_path("remote_items"),
           params: { record: { name: "Widget", owner_id: 2 } },
           as: :html

      creation = a_request(:post, %r{https://api\.example\.com/v1/remote_items})
      expect(creation.with { |http| posted_owner_id(http.body).to_s == "1" }).to have_been_made.once
    end
  end

  def stub_remote_items
    headers = { "Content-Type" => "application/json" }
    stub_request(:get, %r{https://api\.example\.com/v1/remote_items}).to_return(
      status: 200,
      body: [{ id: 1, name: "Widget", owner_id: 1 }].to_json,
      headers: headers
    )
    stub_request(:post, %r{https://api\.example\.com/v1/remote_items}).to_return(
      status: 201,
      body: { id: 9, name: "Widget", owner_id: 1 }.to_json,
      headers: headers
    )
  end

  def set_tenant_scope(&block)
    config = IronAdmin.configuration
    config.tenant_scope = block if config.respond_to?(:tenant_scope=)
    config.tenant_scope(&block) if !IronAdmin::TenantScope.configured? && config.respond_to?(:tenant_scope)
    return if IronAdmin::TenantScope.configured?

    allow(IronAdmin::TenantScope).to receive(:configured?).and_return(true)
    allow(IronAdmin::TenantScope).to receive(:apply) { |scope| block.call(scope) }
  end

  def posted_owner_id(body)
    parsed = JSON.parse(body)
    return parsed["owner_id"] if parsed.is_a?(Hash) && parsed.key?("owner_id")

    child = parsed.values.find { |value| value.is_a?(Hash) && value.key?("owner_id") }
    child && child["owner_id"]
  end
end
