# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::ActionField do
  describe "TYPES" do
    it "includes all supported field types" do
      expect(described_class::TYPES).to eq(%i[text textarea number boolean date datetime select])
    end
  end

  describe "#initialize" do
    context "with minimal arguments" do
      subject(:field) { described_class.new(name: :reason) }

      it "sets name as a symbol" do
        expect(field.name).to eq(:reason)
      end

      it "defaults type to :text" do
        expect(field.type).to eq(:text)
      end

      it "infers label from name" do
        expect(field.label).to eq("Reason")
      end

      it "defaults required to false" do
        expect(field.required).to be(false)
      end

      it "defaults default to nil" do
        expect(field.default).to be_nil
      end

      it "defaults placeholder to nil" do
        expect(field.placeholder).to be_nil
      end

      it "defaults options to nil" do
        expect(field.options).to be_nil
      end
    end

    context "with all arguments" do
      subject(:field) do
        described_class.new(
          name: :priority,
          type: :select,
          label: "Priority Level",
          required: true,
          default: "medium",
          placeholder: "Choose...",
          options: %w[low medium high]
        )
      end

      it "sets the provided type" do
        expect(field.type).to eq(:select)
      end

      it "uses the provided label" do
        expect(field.label).to eq("Priority Level")
      end

      it "sets required to true" do
        expect(field.required).to be(true)
      end

      it "sets the default value" do
        expect(field.default).to eq("medium")
      end

      it "sets the placeholder" do
        expect(field.placeholder).to eq("Choose...")
      end

      it "sets the options array" do
        expect(field.options).to eq(%w[low medium high])
      end
    end

    context "with string name" do
      subject(:field) { described_class.new(name: "duration_days") }

      it "converts to symbol" do
        expect(field.name).to eq(:duration_days)
      end

      it "humanizes multi-word name for label" do
        expect(field.label).to eq("Duration days")
      end
    end

    context "with invalid type" do
      subject(:field) { described_class.new(name: :foo, type: :invalid_type) }

      it "falls back to :text" do
        expect(field.type).to eq(:text)
      end
    end

    context "with string type" do
      subject(:field) { described_class.new(name: :foo, type: "textarea") }

      it "converts to symbol" do
        expect(field.type).to eq(:textarea)
      end
    end

    context "with each supported type" do
      described_class::TYPES.each do |type|
        context "when type is :#{type}" do
          subject(:field) { described_class.new(name: :test, type: type) }

          it "accepts the type" do
            expect(field.type).to eq(type)
          end
        end
      end
    end
  end

  describe "#missing?" do
    context "with a required field" do
      subject(:field) { described_class.new(name: :reason, required: true) }

      it "is missing without a value" do
        expect(field.missing?(nil)).to be(true)
      end

      it "is missing with blank text" do
        expect(field.missing?("  ")).to be(true)
      end

      it "is not missing with a value" do
        expect(field.missing?("Spam")).to be(false)
      end
    end

    context "with an optional field" do
      subject(:field) { described_class.new(name: :reason) }

      it "is not missing without a value" do
        expect(field.missing?(nil)).to be(false)
      end
    end

    # A required checkbox must be checked: "0" and "false" are values, but not a checked box.
    context "with a required boolean field" do
      subject(:field) { described_class.new(name: :i_understand, type: :boolean, required: true) }

      it "is missing when the box was not checked" do
        expect(field.missing?(nil)).to be(true)
      end

      it "is missing with \"0\"" do
        expect(field.missing?("0")).to be(true)
      end

      it "is missing with \"false\"" do
        expect(field.missing?("false")).to be(true)
      end

      it "is missing with blank text" do
        expect(field.missing?("  ")).to be(true)
      end

      it "is not missing with \"1\"" do
        expect(field.missing?("1")).to be(false)
      end

      it "is not missing with \"true\"" do
        expect(field.missing?("true")).to be(false)
      end
    end

    context "with an optional boolean field" do
      subject(:field) { described_class.new(name: :notify, type: :boolean) }

      it "is not missing with \"0\"" do
        expect(field.missing?("0")).to be(false)
      end
    end
  end
end
