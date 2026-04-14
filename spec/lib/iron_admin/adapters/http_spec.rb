# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/http"

RSpec.describe IronAdmin::Adapters::Http do
  subject(:adapter) { described_class.new(model_proxy) }

  let(:config) do
    IronAdmin::Adapters::Http::Configuration.new.tap do |c|
      c.base_url = "https://api.example.com/v1"
      c.resource_path = "/products"
      c.headers = { "Authorization" => "Bearer test" }
    end
  end

  let(:model_proxy) do
    proxy = double(
      "ModelProxy",
      model_name: double("ModelName", plural: "products", human: "Product")
    )
    allow(proxy).to receive(:respond_to?).and_return(false)
    proxy
  end

  let(:sample_records) do
    [
      { id: 1, name: "Widget", price: 10.0, active: true, created_at: "2026-01-01T00:00:00Z" },
      { id: 2, name: "Gadget", price: 20.0, active: false, created_at: "2026-02-01T00:00:00Z" },
    ]
  end

  before do
    adapter.http_config = config

    stub_request(:get, "https://api.example.com/v1/products")
      .to_return(status: 200, body: sample_records.to_json, headers: { "Content-Type" => "application/json" })
  end

  # --- Schema Introspection ---

  describe "#columns" do
    it "returns column descriptors" do
      expect(adapter.columns).to be_an(Array)
    end

    it "returns descriptors responding to name" do
      expect(adapter.columns.first).to respond_to(:name)
    end

    it "returns descriptors responding to type" do
      expect(adapter.columns.first).to respond_to(:type)
    end
  end

  describe "#column_names" do
    it "returns array of strings" do
      expect(adapter.column_names).to include("name", "price")
    end
  end

  describe "#has_column?" do
    it "returns true for known columns" do
      expect(adapter.has_column?(:name)).to be(true)
    end

    it "returns false for unknown columns" do
      expect(adapter.has_column?(:nonexistent)).to be(false)
    end
  end

  describe "#enums" do
    it "returns empty hash" do
      expect(adapter.enums).to eq({})
    end
  end

  describe "#associations" do
    it "returns empty array" do
      expect(adapter.associations).to eq([])
    end

    it "returns empty when filtered by kind" do
      expect(adapter.associations(:belongs_to)).to eq([])
    end
  end

  describe "#association" do
    it "returns nil" do
      expect(adapter.association(:user)).to be_nil
    end
  end

  describe "#attachments" do
    it "returns empty hash" do
      expect(adapter.attachments).to eq({})
    end
  end

  describe "#rich_text_attributes" do
    it "returns empty array" do
      expect(adapter.rich_text_attributes).to eq([])
    end
  end

  # --- Naming ---

  describe "#resource_name" do
    it "returns the plural model name" do
      expect(adapter.resource_name).to eq("products")
    end
  end

  describe "#human_name" do
    it "returns the humanized model name" do
      expect(adapter.human_name).to eq("Product")
    end
  end

  describe "#table_name" do
    it "returns nil for HTTP resources" do
      expect(adapter.table_name).to be_nil
    end
  end

  # --- Query Building ---

  describe "#all" do
    it "returns a Query object" do
      expect(adapter.all).to be_a(IronAdmin::Adapters::Http::Query)
    end
  end

  describe "#find" do
    it "returns a record by id" do
      stub_request(:get, "https://api.example.com/v1/products/1")
        .to_return(status: 200, body: sample_records.first.to_json, headers: { "Content-Type" => "application/json" })

      record = adapter.find(1)
      expect(record.name).to eq("Widget")
    end

    it "raises RecordNotFound for missing records" do
      stub_request(:get, "https://api.example.com/v1/products/999")
        .to_return(status: 404)

      expect { adapter.find(999) }.to raise_error(IronAdmin::RecordNotFound)
    end
  end

  describe "#find_by" do
    it "returns first matching record" do
      stub_request(:get, "https://api.example.com/v1/products")
        .with(query: { name: "Widget" })
        .to_return(status: 200, body: sample_records.to_json, headers: { "Content-Type" => "application/json" })

      result = adapter.find_by(name: "Widget")
      expect(result.name).to eq("Widget")
    end

    it "returns nil when no match" do
      stub_request(:get, "https://api.example.com/v1/products")
        .with(query: { name: "Nonexistent" })
        .to_return(status: 200, body: [].to_json, headers: { "Content-Type" => "application/json" })

      expect(adapter.find_by(name: "Nonexistent")).to be_nil
    end
  end

  describe "#filter" do
    it "returns a filtered query" do
      scope = adapter.all
      filtered = adapter.filter(scope, :active, true)
      expect(filtered).to be_a(IronAdmin::Adapters::Http::Query)
    end
  end

  describe "#order_by" do
    it "returns an ordered query" do
      scope = adapter.all
      ordered = adapter.order_by(scope, :name, :asc)
      expect(ordered).to be_a(IronAdmin::Adapters::Http::Query)
    end
  end

  describe "#limit" do
    it "returns a limited query" do
      scope = adapter.all
      limited = adapter.limit(scope, 10)
      expect(limited).to be_a(IronAdmin::Adapters::Http::Query)
    end
  end

  describe "#preload" do
    it "returns the scope unchanged" do
      scope = adapter.all
      expect(adapter.preload(scope, [:user])).to eq(scope)
    end
  end

  describe "#distinct_values" do
    it "returns sorted unique values" do
      values = adapter.distinct_values(:active)
      expect(values).to eq([false, true])
    end
  end

  describe "#pluck" do
    it "extracts column values from a scope" do
      ids = adapter.pluck(adapter.all, "id")
      expect(ids).to eq([1, 2])
    end
  end

  describe "#unscope_column" do
    it "returns the scope unchanged" do
      scope = adapter.all
      expect(adapter.unscope_column(scope, :deleted_at)).to eq(scope)
    end
  end

  describe "#find_each" do
    it "iterates all records" do
      names = []
      adapter.find_each(adapter.all) { |r| names << r.name }
      expect(names.length).to eq(2)
    end
  end

  describe "#count" do
    it "counts all records" do
      expect(adapter.count).to eq(2)
    end

    it "counts records in a scope" do
      scope = adapter.all
      expect(adapter.count(scope)).to eq(2)
    end
  end

  # --- Search ---

  describe "#search_column" do
    it "returns a query" do
      result = adapter.search_column(adapter.all, :name, "Widget")
      expect(result).to be_a(IronAdmin::Adapters::Http::Query)
    end
  end

  describe "#search_columns" do
    it "returns a query" do
      result = adapter.search_columns(adapter.all, %i[name], "Widget")
      expect(result).to be_a(IronAdmin::Adapters::Http::Query)
    end
  end

  # --- CRUD ---

  describe "#build" do
    it "returns a new unsaved record" do
      record = adapter.build(name: "New Product")
      expect(record).to be_a(IronAdmin::Adapters::Http::Record)
      expect(record).not_to be_persisted
    end
  end

  describe "#save" do
    it "creates a new record via POST" do
      stub_request(:post, "https://api.example.com/v1/products")
        .to_return(status: 201, body: { id: 3, name: "New" }.to_json, headers: { "Content-Type" => "application/json" })

      record = adapter.build(name: "New")
      expect(adapter.save(record)).to be(true)
      expect(record).to be_persisted
    end

    it "returns false on failure" do
      stub_request(:post, "https://api.example.com/v1/products")
        .to_return(status: 422, body: { errors: { name: ["is required"] } }.to_json)

      record = adapter.build
      expect(adapter.save(record)).to be(false)
    end
  end

  describe "#update" do
    it "updates via PATCH" do
      stub_request(:patch, "https://api.example.com/v1/products/1")
        .to_return(status: 200, body: { id: 1, name: "Updated" }.to_json, headers: { "Content-Type" => "application/json" })

      record = IronAdmin::Adapters::Http::Record.new(id: 1, name: "Old")
      expect(adapter.update(record, name: "Updated")).to be(true)
    end
  end

  describe "#destroy!" do
    it "deletes via DELETE" do
      stub_request(:delete, "https://api.example.com/v1/products/1")
        .to_return(status: 204)

      record = IronAdmin::Adapters::Http::Record.new(id: 1)
      adapter.destroy!(record)
      expect(a_request(:delete, "https://api.example.com/v1/products/1")).to have_been_made
    end
  end

  # --- Transactions ---

  describe "#transaction" do
    it "yields the block" do
      expect(adapter.transaction { "done" }).to eq("done")
    end
  end

  # --- Adapter-Agnostic ---

  describe "#record_changes" do
    it "returns previous_changes" do
      record = IronAdmin::Adapters::Http::Record.new(id: 1, name: "Old")
      record.assign_attributes(name: "New")
      record.mark_as_persisted
      expect(adapter.record_changes(record)).to have_key("name")
    end
  end

  describe "#wrap_rollback" do
    it "silences IronAdmin::Rollback" do
      expect { adapter.wrap_rollback { raise IronAdmin::Rollback } }.not_to raise_error
    end
  end

  describe "#query_builder_class" do
    it "returns HttpQueryBuilder" do
      expect(adapter.query_builder_class).to eq(IronAdmin::Filters::HttpQueryBuilder)
    end
  end

  describe "#pagy_method" do
    it "returns :pagy" do
      expect(adapter.pagy_method).to eq(:pagy)
    end
  end

  describe "#cast_boolean" do
    it "casts 'true' to true" do
      expect(adapter.cast_boolean("true")).to be(true)
    end

    it "casts 'false' to false" do
      expect(adapter.cast_boolean("false")).to be(false)
    end
  end
end
