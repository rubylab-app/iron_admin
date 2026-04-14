# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/http"

RSpec.describe IronAdmin::Adapters::Http::Record do
  describe "#initialize" do
    it "accepts a hash of attributes" do
      record = described_class.new(id: "abc123", name: "Product A", price: 29.99)
      expect(record.id).to eq("abc123")
    end
  end

  describe "dynamic attribute access" do
    subject(:record) { described_class.new(id: "1", name: "Widget", price: 9.99, active: true) }

    it "responds to attribute readers" do
      expect(record.name).to eq("Widget")
    end

    it "responds to numeric attributes" do
      expect(record.price).to eq(9.99)
    end

    it "responds to boolean attributes" do
      expect(record.active).to be(true)
    end

    it "raises NoMethodError for unknown attributes" do
      expect { record.nonexistent }.to raise_error(NoMethodError)
    end

    it "responds to respond_to? for known attributes" do
      expect(record).to respond_to(:name)
    end
  end

  describe "#id" do
    it "returns the id attribute" do
      record = described_class.new(id: "abc123")
      expect(record.id).to eq("abc123")
    end

    it "returns nil when no id" do
      record = described_class.new(name: "Test")
      expect(record.id).to be_nil
    end
  end

  describe "#to_param" do
    it "returns id as string for URL generation" do
      record = described_class.new(id: 42)
      expect(record.to_param).to eq("42")
    end
  end

  describe "#persisted?" do
    it "returns true when record has an id" do
      record = described_class.new(id: "abc123")
      expect(record).to be_persisted
    end

    it "returns false when record has no id" do
      record = described_class.new(name: "Test")
      expect(record).not_to be_persisted
    end
  end

  describe "#new_record?" do
    it "returns false when persisted" do
      record = described_class.new(id: "abc123")
      expect(record).not_to be_new_record
    end

    it "returns true when not persisted" do
      record = described_class.new(name: "Test")
      expect(record).to be_new_record
    end
  end

  describe "change tracking" do
    subject(:record) { described_class.new(id: "1", name: "Old Name", price: 10) }

    it "tracks attribute changes via assign_attributes" do
      record.assign_attributes(name: "New Name")
      expect(record.changes).to have_key("name")
    end

    it "returns previous_changes after mark_as_persisted" do
      record.assign_attributes(name: "New Name")
      record.mark_as_persisted
      expect(record.previous_changes).to have_key("name")
    end

    it "clears current changes after mark_as_persisted" do
      record.assign_attributes(name: "New Name")
      record.mark_as_persisted
      expect(record.changes).to be_empty
    end
  end

  describe "#attributes" do
    it "returns all attributes as a hash" do
      record = described_class.new(id: "1", name: "Widget", price: 9.99)
      expect(record.attributes).to eq("id" => "1", "name" => "Widget", "price" => 9.99)
    end
  end

  describe "#[]" do
    it "accesses attributes by key" do
      record = described_class.new(name: "Widget")
      expect(record[:name]).to eq("Widget")
    end

    it "accesses attributes by string key" do
      record = described_class.new(name: "Widget")
      expect(record["name"]).to eq("Widget")
    end
  end
end
