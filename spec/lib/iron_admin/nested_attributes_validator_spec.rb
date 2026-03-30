# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::NestedAttributesValidator do
  describe ".validate!" do
    context "when model declares accepts_nested_attributes_for" do
      it "does not raise" do
        expect { described_class.validate!(User, :licenses) }.not_to raise_error
      end
    end

    context "when model does NOT declare accepts_nested_attributes_for" do
      it "raises ArgumentError with helpful message" do
        expect { described_class.validate!(User, :profile) }.to raise_error(
          ArgumentError,
          /User must declare `accepts_nested_attributes_for :profile`/
        )
      end
    end

    context "when association name is a string" do
      it "converts to symbol for lookup" do
        expect { described_class.validate!(User, "licenses") }.not_to raise_error
      end
    end
  end
end
