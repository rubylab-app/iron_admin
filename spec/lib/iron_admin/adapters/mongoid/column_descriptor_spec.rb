# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/mongoid"

RSpec.describe IronAdmin::Adapters::Mongoid::ColumnDescriptor do
  subject(:descriptor) { described_class.new("email", :string) }

  describe "#name" do
    it "returns the column name" do
      expect(descriptor.name).to eq("email")
    end

    context "when field is _id" do
      subject(:descriptor) { described_class.new("_id", :string) }

      it "stores _id as name" do
        expect(descriptor.name).to eq("_id")
      end
    end
  end

  describe "#type" do
    it "returns the column type" do
      expect(descriptor.type).to eq(:string)
    end
  end

  describe "#to_s" do
    it "returns the column name as string" do
      expect(descriptor.to_s).to eq("email")
    end
  end
end
