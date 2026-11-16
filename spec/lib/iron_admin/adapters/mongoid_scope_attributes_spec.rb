# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Adapters::Mongoid do
  describe "#scope_attributes" do
    it "uses the adapter model when the scope does not expose klass" do
      model = Class.new do
        def self.fields
          { "user_id" => true, "title" => true }
        end
      end
      adapter = described_class.new(model)
      scope = Object.new
      scope.define_singleton_method(:selector) do
        { "user_id" => 9, "missing" => true, "tags" => { "$in" => ["a"] }, "ids" => [1] }
      end

      expect(adapter.scope_attributes(scope)).to eq("user_id" => 9)
    end
  end
end
