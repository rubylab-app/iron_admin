# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Adapters::Registry do
  describe ".resolve" do
    it "resolves :active_record to the ActiveRecord adapter class" do
      expect(described_class.resolve(:active_record)).to eq(IronAdmin::Adapters::ActiveRecord)
    end

    it "raises ArgumentError for unknown adapter identifiers" do
      expect { described_class.resolve(:unknown) }.to raise_error(ArgumentError, /Unknown adapter/)
    end

    it "returns a class that can be instantiated with a model" do
      klass = described_class.resolve(:active_record)
      adapter = klass.new(User)
      expect(adapter).to be_a(IronAdmin::Adapters::Base)
    end
  end
end
