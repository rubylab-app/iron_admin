# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::NestedAssociation do
  describe "struct attributes" do
    subject(:nested) do
      described_class.new(
        name: :line_items,
        kind: :has_many,
        reflection: double("reflection"),
        fields: [IronAdmin::Field.new(:product, type: :text)],
        allow_destroy: true,
        position_field: :position
      )
    end

    it "stores name" do
      expect(nested.name).to eq(:line_items)
    end

    it "stores kind" do
      expect(nested.kind).to eq(:has_many)
    end

    it "stores reflection" do
      expect(nested.reflection).to be_present
    end

    it "stores fields" do
      expect(nested.fields.length).to eq(1)
      expect(nested.fields.first.name).to eq(:product)
    end

    it "stores allow_destroy" do
      expect(nested.allow_destroy).to be(true)
    end

    it "stores position_field" do
      expect(nested.position_field).to eq(:position)
    end
  end

  describe "defaults" do
    subject(:nested) do
      described_class.new(
        name: :address,
        kind: :has_one,
        reflection: double("reflection"),
        fields: [],
        allow_destroy: false,
        position_field: nil
      )
    end

    it "allows nil position_field" do
      expect(nested.position_field).to be_nil
    end

    it "allows false allow_destroy" do
      expect(nested.allow_destroy).to be(false)
    end
  end
end
