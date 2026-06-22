# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/mongoid"

RSpec.describe IronAdmin::Filters::MongoidQueryBuilder do
  let(:scope) { double("Criteria") }

  describe ".call" do
    context "with string filter" do
      let(:filter) { { name: :name, type: :string } }

      it "applies contains operator with regex" do
        filtered = double("Filtered")
        allow(scope).to receive(:where).and_return(filtered)
        result = described_class.call(scope, filter, "op" => "contains", "value" => "Alice")
        expect(result).to eq(filtered)
      end

      it "applies equals operator with exact match" do
        filtered = double("Filtered")
        allow(scope).to receive(:where).with(name: "Alice").and_return(filtered)
        result = described_class.call(scope, filter, "op" => "equals", "value" => "Alice")
        expect(result).to eq(filtered)
      end

      it "applies starts_with operator" do
        filtered = double("Filtered")
        allow(scope).to receive(:where).and_return(filtered)
        result = described_class.call(scope, filter, "op" => "starts_with", "value" => "Ali")
        expect(result).to eq(filtered)
      end

      it "applies ends_with operator" do
        filtered = double("Filtered")
        allow(scope).to receive(:where).and_return(filtered)
        result = described_class.call(scope, filter, "op" => "ends_with", "value" => "ice")
        expect(result).to eq(filtered)
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
      let(:filter) { { name: :age, type: :number } }

      it "applies equals operator" do
        filtered = double("Filtered")
        allow(scope).to receive(:where).with("age" => 25).and_return(filtered)
        result = described_class.call(scope, filter, "op" => "equals", "value" => "25")
        expect(result).to eq(filtered)
      end

      it "applies greater_than operator with $gt" do
        filtered = double("Filtered")
        allow(scope).to receive(:where).with("age" => { "$gt" => 18 }).and_return(filtered)
        result = described_class.call(scope, filter, "op" => "greater_than", "value" => "18")
        expect(result).to eq(filtered)
      end

      it "applies less_than operator with $lt" do
        filtered = double("Filtered")
        allow(scope).to receive(:where).with("age" => { "$lt" => 65 }).and_return(filtered)
        result = described_class.call(scope, filter, "op" => "less_than", "value" => "65")
        expect(result).to eq(filtered)
      end

      it "applies between operator with $gte and $lte" do
        filtered = double("Filtered")
        allow(scope).to receive(:where).with("age" => { "$gte" => 18, "$lte" => 65 }).and_return(filtered)
        result = described_class.call(scope, filter, "op" => "between", "value" => "18", "value_2" => "65")
        expect(result).to eq(filtered)
      end

      it "returns unmodified scope for non-numeric value" do
        result = described_class.call(scope, filter, "op" => "equals", "value" => "abc")
        expect(result).to eq(scope)
      end

      it "returns unmodified scope for between with invalid upper value" do
        result = described_class.call(scope, filter, "op" => "between", "value" => "18", "value_2" => "abc")
        expect(result).to eq(scope)
      end

      it "handles float values" do
        filtered = double("Filtered")
        allow(scope).to receive(:where).with("age" => 25.5).and_return(filtered)
        result = described_class.call(scope, filter, "op" => "equals", "value" => "25.5")
        expect(result).to eq(filtered)
      end

      it "ignores integer values that BSON cannot encode" do
        allow(scope).to receive(:where)

        result = described_class.call(
          scope,
          filter,
          "op" => "less_than",
          "value" => "999999999999999999999999"
        )

        expect(result).to eq(scope)
        expect(scope).not_to have_received(:where)
      end

      it "ignores between filters when the upper value is outside BSON int64 range" do
        allow(scope).to receive(:where)

        result = described_class.call(
          scope,
          filter,
          "op" => "between",
          "value" => "1",
          "value_2" => "999999999999999999999999"
        )

        expect(result).to eq(scope)
        expect(scope).not_to have_received(:where)
      end
    end

    context "with unknown filter type" do
      let(:filter) { { name: :custom, type: :custom } }

      it "returns unmodified scope" do
        result = described_class.call(scope, filter, "op" => "equals", "value" => "test")
        expect(result).to eq(scope)
      end
    end
  end
end
