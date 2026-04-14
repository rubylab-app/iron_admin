# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/http"

RSpec.describe IronAdmin::Adapters::Http::Connection do
  subject(:connection) { described_class.new(config) }

  let(:config) do
    IronAdmin::Adapters::Http::Configuration.new.tap do |c|
      c.base_url = "https://api.example.com/v1"
      c.resource_path = "/products"
      c.headers = { "Authorization" => "Bearer test-token" }
    end
  end

  describe "#initialize" do
    it "stores the configuration" do
      expect(connection).to be_a(described_class)
    end
  end

  describe "#get" do
    it "performs a GET request with params" do
      stub_request(:get, "https://api.example.com/v1/products")
        .with(query: { status: "active" }, headers: { "Authorization" => "Bearer test-token" })
        .to_return(status: 200, body: [{ id: 1, name: "Widget" }].to_json, headers: { "Content-Type" => "application/json" })

      response = connection.get(params: { status: "active" })
      expect(response[:data].length).to eq(1)
      expect(response[:data].first["name"]).to eq("Widget")
    end

    it "extracts total from response meta" do
      body = { data: [{ id: 1 }], meta: { total: 50 } }.to_json
      stub_request(:get, "https://api.example.com/v1/products")
        .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

      response = connection.get
      expect(response[:total]).to eq(50)
    end

    it "handles plain array responses" do
      stub_request(:get, "https://api.example.com/v1/products")
        .to_return(status: 200, body: [{ id: 1 }, { id: 2 }].to_json, headers: { "Content-Type" => "application/json" })

      response = connection.get
      expect(response[:data].length).to eq(2)
      expect(response[:total]).to be_nil
    end
  end

  describe "#get_one" do
    it "performs a GET request for a single record" do
      stub_request(:get, "https://api.example.com/v1/products/42")
        .with(headers: { "Authorization" => "Bearer test-token" })
        .to_return(status: 200, body: { id: 42, name: "Widget" }.to_json, headers: { "Content-Type" => "application/json" })

      data = connection.get_one("42")
      expect(data["name"]).to eq("Widget")
    end

    it "raises RecordNotFound for 404" do
      stub_request(:get, "https://api.example.com/v1/products/999")
        .to_return(status: 404, body: { error: "Not found" }.to_json)

      expect { connection.get_one("999") }.to raise_error(IronAdmin::RecordNotFound)
    end
  end

  describe "#post" do
    it "creates a record" do
      stub_request(:post, "https://api.example.com/v1/products")
        .with(body: { name: "New Widget" }.to_json, headers: { "Authorization" => "Bearer test-token" })
        .to_return(status: 201, body: { id: 1, name: "New Widget" }.to_json, headers: { "Content-Type" => "application/json" })

      data = connection.post(name: "New Widget")
      expect(data["id"]).to eq(1)
    end
  end

  describe "#patch" do
    it "updates a record" do
      stub_request(:patch, "https://api.example.com/v1/products/1")
        .with(body: { name: "Updated" }.to_json)
        .to_return(status: 200, body: { id: 1, name: "Updated" }.to_json, headers: { "Content-Type" => "application/json" })

      data = connection.patch("1", name: "Updated")
      expect(data["name"]).to eq("Updated")
    end
  end

  describe "#delete" do
    it "deletes a record" do
      stub_request(:delete, "https://api.example.com/v1/products/1")
        .to_return(status: 204, body: "")

      expect { connection.delete("1") }.not_to raise_error
    end
  end

  describe "error handling" do
    it "raises RecordNotFound for 404 on get" do
      stub_request(:get, "https://api.example.com/v1/products")
        .to_return(status: 404)

      expect { connection.get }.to raise_error(IronAdmin::RecordNotFound)
    end

    it "raises AdapterError for 500" do
      stub_request(:get, "https://api.example.com/v1/products")
        .to_return(status: 500, body: "Internal Server Error")

      expect { connection.get }.to raise_error(IronAdmin::AdapterError)
    end

    it "raises AdapterError for network errors" do
      stub_request(:get, "https://api.example.com/v1/products")
        .to_timeout

      expect { connection.get }.to raise_error(IronAdmin::AdapterError)
    end
  end
end
