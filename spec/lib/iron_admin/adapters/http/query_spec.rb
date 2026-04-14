# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/http"

RSpec.describe IronAdmin::Adapters::Http::Query do
  subject(:query) { described_class.new(connection) }

  let(:config) do
    IronAdmin::Adapters::Http::Configuration.new.tap do |c|
      c.base_url = "https://api.example.com/v1"
      c.resource_path = "/products"
    end
  end

  let(:connection) { IronAdmin::Adapters::Http::Connection.new(config) }

  before do
    stub_request(:get, "https://api.example.com/v1/products")
      .to_return(
        status: 200,
        body: [
          { id: 1, name: "Widget", price: 10, status: "active" },
          { id: 2, name: "Gadget", price: 20, status: "inactive" },
          { id: 3, name: "Doohickey", price: 30, status: "active" },
        ].to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  describe "lazy execution" do
    it "does not make HTTP request on initialization" do
      described_class.new(connection)
      expect(a_request(:get, "https://api.example.com/v1/products")).not_to have_been_made
    end

    it "makes HTTP request when iterated" do
      query.to_a
      expect(a_request(:get, "https://api.example.com/v1/products")).to have_been_made.once
    end
  end

  describe "Enumerable" do
    it "includes Enumerable" do
      expect(described_class).to include(Enumerable)
    end

    it "iterates over records" do
      names = query.map(&:name)
      expect(names).to eq(%w[Widget Gadget Doohickey])
    end
  end

  describe "#each" do
    it "yields Http::Record objects" do
      record = query.first
      expect(record).to be_a(IronAdmin::Adapters::Http::Record)
    end
  end

  describe "#count" do
    it "returns the number of records" do
      expect(query.count).to eq(3)
    end

    context "when API returns total in meta" do
      before do
        stub_request(:get, "https://api.example.com/v1/products")
          .to_return(
            status: 200,
            body: { data: [{ id: 1 }], meta: { total: 100 } }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns meta total" do
        expect(query.count).to eq(100)
      end
    end
  end

  describe "#first" do
    it "returns the first record" do
      expect(query.first.name).to eq("Widget")
    end

    it "returns nil when no records" do
      stub_request(:get, "https://api.example.com/v1/products")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      expect(query.first).to be_nil
    end
  end

  describe "#where" do
    it "returns a new query with accumulated params" do
      filtered = query.where(status: "active")
      expect(filtered).not_to eq(query)
      expect(filtered).to be_a(described_class)
    end

    it "sends params in the HTTP request" do
      stub_request(:get, "https://api.example.com/v1/products")
        .with(query: { status: "active" })
        .to_return(status: 200, body: [{ id: 1 }].to_json, headers: { "Content-Type" => "application/json" })

      filtered = query.where(status: "active")
      filtered.to_a
      expect(a_request(:get, "https://api.example.com/v1/products").with(query: { status: "active" }))
        .to have_been_made
    end

    it "accumulates multiple where calls" do
      stub_request(:get, "https://api.example.com/v1/products")
        .with(query: { status: "active", category: "tools" })
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      query.where(status: "active").where(category: "tools").to_a
      expect(a_request(:get, "https://api.example.com/v1/products")
        .with(query: { status: "active", category: "tools" }))
        .to have_been_made
    end
  end

  describe "#order" do
    it "returns a new query with sort params" do
      ordered = query.order(name: :asc)
      expect(ordered).to be_a(described_class)
    end

    it "serializes sort into request params" do
      stub_request(:get, "https://api.example.com/v1/products")
        .with(query: { sort: "name:asc" })
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      query.order(name: :asc).to_a
      expect(a_request(:get, "https://api.example.com/v1/products")
        .with(query: { sort: "name:asc" }))
        .to have_been_made
    end

    it "serializes multi-column sort" do
      stub_request(:get, "https://api.example.com/v1/products")
        .with(query: { sort: "name:asc,created_at:desc" })
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      query.order(name: :asc).order(created_at: :desc).to_a
      expect(a_request(:get, "https://api.example.com/v1/products")
        .with(query: { sort: "name:asc,created_at:desc" }))
        .to have_been_made
    end
  end

  describe "#offset" do
    it "returns a new query with offset" do
      offset_query = query.offset(10)
      expect(offset_query).to be_a(described_class)
    end
  end

  describe "#limit" do
    it "returns a new query with limit" do
      limited = query.limit(2)
      expect(limited).to be_a(described_class)
    end
  end

  describe "#merge" do
    it "merges another query's params" do
      other = described_class.new(connection).where(status: "active")
      merged = query.merge(other)
      expect(merged).to be_a(described_class)
    end

    it "ignores non-query objects" do
      result = query.merge(-> { "something" })
      expect(result).to be_a(described_class)
    end
  end

  describe "#empty?" do
    it "returns false when records exist" do
      expect(query).not_to be_empty
    end

    it "returns true when no records" do
      stub_request(:get, "https://api.example.com/v1/products")
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      expect(query).to be_empty
    end
  end
end
