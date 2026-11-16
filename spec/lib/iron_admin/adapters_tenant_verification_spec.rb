# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/active_record"
require "iron_admin/adapters/mongoid"
require "iron_admin/adapters/http"

RSpec.describe IronAdmin::Adapters do
  describe IronAdmin::Adapters::Base do
    subject(:adapter) { described_class.new(double("model").as_null_object) }

    it "does not support transactions" do
      expect(adapter.supports_transactions?).to be(false)
    end

    it "cannot tell whether a record is in scope" do
      expect(adapter.scope_match(double("scope"), double("record"))).to eq(:unknown)
    end

    it "cannot preview an update" do
      expect(adapter.preview(double("record"), { "name" => "New" })).to be_nil
    end
  end

  describe IronAdmin::Adapters::ActiveRecord do
    it "supports transactions" do
      adapter = described_class.new(User)

      expect(adapter.supports_transactions?).to be(true)
    end
  end

  describe IronAdmin::Adapters::Mongoid do
    subject(:adapter) { described_class.new(double("MongoidModel").as_null_object) }

    it "does not support transactions" do
      expect(adapter.supports_transactions?).to be(false)
    end

    it "returns :inside when the document matches the selector" do
      selector = { "owner_id" => 3 }
      scope = double("criteria", selector: selector)
      record = double("document")
      allow(record).to receive(:_matches?).with(selector).and_return(true)

      expect(adapter.scope_match(scope, record)).to eq(:inside)
    end

    it "returns :outside when _matches? is false" do
      selector = { "owner_id" => 3 }
      scope = double("criteria", selector: selector)
      record = double("document")
      allow(record).to receive(:_matches?).with(selector).and_return(false)

      expect(adapter.scope_match(scope, record)).to eq(:outside)
    end

    it "is unknown when the record does not implement _matches?" do
      scope = double("criteria", selector: { "owner_id" => 3 })
      record = double("document")

      expect(adapter.scope_match(scope, record)).to eq(:unknown)
    end
  end

  describe IronAdmin::Adapters::Http do
    subject(:adapter) { described_class.new(model_proxy) }

    let(:model_proxy) do
      proxy = double(
        "ModelProxy",
        model_name: double("ModelName", plural: "products", human: "Product")
      )
      allow(proxy).to receive(:respond_to?).and_return(false)
      proxy
    end

    let(:config) do
      IronAdmin::Adapters::Http::Configuration.new.tap do |http|
        http.base_url = "https://api.example.com/v1"
        http.resource_path = "/products"
        http.headers = { "Authorization" => "Bearer test" }
      end
    end

    before { adapter.http_config = config }

    it "does not support transactions" do
      expect(adapter.supports_transactions?).to be(false)
    end

    it "reads scalar equalities and drops IN lists" do
      scalar_scope = adapter.all
      list_scope = adapter.all

      expect(adapter.scope_attributes(scalar_scope.where(owner_id: 7))).to eq({ "owner_id" => 7 })
      expect(adapter.scope_attributes(list_scope.where(owner_id: [7, 8]))).to eq({})
    end

    it "matches a record against scalar equalities" do
      scope = adapter.all
      scope = scope.where(owner_id: 7)
      inside = IronAdmin::Adapters::Http::Record.new("owner_id" => 7, "name" => "In")
      outside = IronAdmin::Adapters::Http::Record.new("owner_id" => 8, "name" => "Out")

      expect(adapter.scope_match(scope, inside)).to eq(:inside)
      expect(adapter.scope_match(scope, outside)).to eq(:outside)
    end

    it "is unknown for an IN-list query" do
      scope = adapter.all
      scope = scope.where(owner_id: [7, 8])
      record = IronAdmin::Adapters::Http::Record.new("owner_id" => 7)

      expect(adapter.scope_match(scope, record)).to eq(:unknown)
    end

    it "previews an unsaved copy with the merged values" do
      source = IronAdmin::Adapters::Http::Record.new("id" => 5, "name" => "Old", "owner_id" => 7)

      copy = adapter.preview(source, { name: "New", owner_id: 9 })

      expect(copy).not_to be_persisted
      expect(copy).not_to equal(source)
      expect(copy.attributes).to include("name" => "New", "owner_id" => 9)
      expect(source.attributes).to include("name" => "Old", "owner_id" => 7)
    end
  end
end
