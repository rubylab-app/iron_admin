# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/http"

RSpec.describe IronAdmin::Adapters::Http::TypeInferrer do
  describe ".infer" do
    it "infers :number from integers" do
      expect(described_class.infer(42)).to eq(:number)
    end

    it "infers :number from floats" do
      expect(described_class.infer(29.99)).to eq(:number)
    end

    it "infers :boolean from true" do
      expect(described_class.infer(true)).to eq(:boolean)
    end

    it "infers :boolean from false" do
      expect(described_class.infer(false)).to eq(:boolean)
    end

    it "infers :datetime from ISO 8601 strings with time" do
      expect(described_class.infer("2026-04-13T01:48:11Z")).to eq(:datetime)
    end

    it "infers :datetime from ISO 8601 with offset" do
      expect(described_class.infer("2026-04-13T10:30:00+05:00")).to eq(:datetime)
    end

    it "infers :date from date-only strings" do
      expect(described_class.infer("2026-04-13")).to eq(:date)
    end

    it "infers :json from hashes" do
      expect(described_class.infer({ "nested" => "value" })).to eq(:json)
    end

    it "infers :json from arrays" do
      expect(described_class.infer([1, 2, 3])).to eq(:json)
    end

    it "infers :string from nil" do
      expect(described_class.infer(nil)).to eq(:string)
    end

    it "infers :string from plain strings" do
      expect(described_class.infer("hello world")).to eq(:string)
    end

    it "infers :string from empty strings" do
      expect(described_class.infer("")).to eq(:string)
    end

    it "does not confuse short numeric strings as dates" do
      expect(described_class.infer("12345")).to eq(:string)
    end
  end

  describe ".infer_columns" do
    it "infers column descriptors from a JSON hash" do
      data = { "id" => "abc", "name" => "Widget", "price" => 29.99, "active" => true }
      columns = described_class.infer_columns(data)

      expect(columns.length).to eq(4)
      expect(columns.map(&:name)).to contain_exactly("id", "name", "price", "active")
    end

    it "maps types correctly" do
      data = { "id" => 1, "title" => "Hello", "published" => false, "created_at" => "2026-01-01T00:00:00Z" }
      columns = described_class.infer_columns(data)

      types = columns.to_h { |c| [c.name, c.type] }
      expect(types["id"]).to eq(:number)
      expect(types["title"]).to eq(:string)
      expect(types["published"]).to eq(:boolean)
      expect(types["created_at"]).to eq(:datetime)
    end

    it "returns empty array for empty hash" do
      expect(described_class.infer_columns({})).to eq([])
    end
  end
end
