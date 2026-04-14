# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/http"

RSpec.describe IronAdmin::Filters::HttpQueryBuilder do
  let(:config) do
    IronAdmin::Adapters::Http::Configuration.new.tap do |c|
      c.base_url = "https://api.example.com/v1"
      c.resource_path = "/items"
    end
  end

  let(:connection) { IronAdmin::Adapters::Http::Connection.new(config) }
  let(:scope) { IronAdmin::Adapters::Http::Query.new(connection) }

  describe ".call" do
    context "with string filter" do
      let(:filter) { { name: :title, type: :string } }

      it "applies contains operator" do
        result = described_class.call(scope, filter, "op" => "contains", "value" => "widget")
        expect(result).to be_a(IronAdmin::Adapters::Http::Query)
      end

      it "applies equals operator" do
        result = described_class.call(scope, filter, "op" => "equals", "value" => "widget")
        expect(result).to be_a(IronAdmin::Adapters::Http::Query)
      end

      it "applies starts_with operator" do
        result = described_class.call(scope, filter, "op" => "starts_with", "value" => "wid")
        expect(result).to be_a(IronAdmin::Adapters::Http::Query)
      end

      it "applies ends_with operator" do
        result = described_class.call(scope, filter, "op" => "ends_with", "value" => "get")
        expect(result).to be_a(IronAdmin::Adapters::Http::Query)
      end

      it "returns unmodified scope for blank value" do
        result = described_class.call(scope, filter, "op" => "contains", "value" => "")
        expect(result).to eq(scope)
      end

      it "returns unmodified scope for invalid operator" do
        result = described_class.call(scope, filter, "op" => "invalid", "value" => "test")
        expect(result).to eq(scope)
      end
    end

    context "with number filter" do
      let(:filter) { { name: :price, type: :number } }

      it "applies equals operator" do
        result = described_class.call(scope, filter, "op" => "equals", "value" => "25")
        expect(result).to be_a(IronAdmin::Adapters::Http::Query)
      end

      it "applies greater_than operator" do
        result = described_class.call(scope, filter, "op" => "greater_than", "value" => "10")
        expect(result).to be_a(IronAdmin::Adapters::Http::Query)
      end

      it "applies less_than operator" do
        result = described_class.call(scope, filter, "op" => "less_than", "value" => "50")
        expect(result).to be_a(IronAdmin::Adapters::Http::Query)
      end

      it "applies between operator" do
        result = described_class.call(scope, filter, "op" => "between", "value" => "10", "value_2" => "50")
        expect(result).to be_a(IronAdmin::Adapters::Http::Query)
      end

      it "returns unmodified scope for non-numeric value" do
        result = described_class.call(scope, filter, "op" => "equals", "value" => "abc")
        expect(result).to eq(scope)
      end

      it "returns unmodified scope for between with invalid upper" do
        result = described_class.call(scope, filter, "op" => "between", "value" => "10", "value_2" => "abc")
        expect(result).to eq(scope)
      end
    end
  end
end
