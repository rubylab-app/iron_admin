# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe IronAdmin::ToolAction do
  describe "#initialize" do
    context "with minimal arguments" do
      subject(:action) { described_class.new(name: :generate) }

      it "stores name as symbol" do
        expect(action.name).to eq(:generate)
      end

      it "infers label from name" do
        expect(action.label).to eq("Generate")
      end

      it "defaults icon to nil" do
        expect(action.icon).to be_nil
      end

      it "defaults confirm to false" do
        expect(action.confirm).to be(false)
      end

      it "defaults confirm_message to nil" do
        expect(action.confirm_message).to be_nil
      end

      it "defaults form_fields to empty array" do
        expect(action.form_fields).to eq([])
      end

      it "defaults condition to nil" do
        expect(action.condition).to be_nil
      end
    end

    context "with all arguments" do
      subject(:action) do
        described_class.new(
          name: :run_migration,
          label: "Execute Migration",
          icon: "play",
          confirm: true,
          confirm_message: "Are you sure?",
          form_fields: [{ name: :reason, type: :textarea }],
          condition: ->(u) { u&.admin? }
        )
      end

      it "stores the provided label" do
        expect(action.label).to eq("Execute Migration")
      end

      it "stores the icon" do
        expect(action.icon).to eq("play")
      end

      it "stores confirm as true" do
        expect(action.confirm).to be(true)
      end

      it "stores the confirm message" do
        expect(action.confirm_message).to eq("Are you sure?")
      end

      it "stores the condition proc" do
        expect(action.condition).to be_a(Proc)
      end
    end

    context "with string name" do
      subject(:action) { described_class.new(name: "run_report") }

      it "converts to symbol" do
        expect(action.name).to eq(:run_report)
      end

      it "humanizes for label" do
        expect(action.label).to eq("Run report")
      end
    end
  end

  describe "form_fields coercion" do
    context "with hash form_fields" do
      subject(:action) { described_class.new(name: :x, form_fields: [{ name: :reason, type: :textarea }]) }

      it "coerces to ActionField instances" do
        expect(action.form_fields.first).to be_a(IronAdmin::ActionField)
        expect(action.form_fields.first.name).to eq(:reason)
      end
    end

    context "with ActionField instances" do
      subject(:action) { described_class.new(name: :x, form_fields: [field]) }

      let(:field) { IronAdmin::ActionField.new(name: :reason, type: :textarea) }

      it "preserves them as-is" do
        expect(action.form_fields.first).to eq(field)
      end
    end
  end

  describe "#has_form?" do
    context "when form_fields are present" do
      subject(:action) { described_class.new(name: :x, form_fields: [{ name: :reason }]) }

      it "returns true" do
        expect(action.has_form?).to be(true)
      end
    end

    context "when form_fields are empty" do
      subject(:action) { described_class.new(name: :x) }

      it "returns false" do
        expect(action.has_form?).to be(false)
      end
    end
  end

  describe "#allowed?" do
    context "without condition" do
      subject(:action) { described_class.new(name: :x) }

      it "returns true for any user" do
        expect(action.allowed?(nil)).to be(true)
      end
    end

    context "with condition" do
      subject(:action) { described_class.new(name: :x, condition: ->(u) { u&.admin? }) }

      let(:admin) { OpenStruct.new(admin?: true) }
      let(:regular) { OpenStruct.new(admin?: false) }

      it "returns true when condition passes" do
        expect(action.allowed?(admin)).to be(true)
      end

      it "returns false when condition fails" do
        expect(action.allowed?(regular)).to be(false)
      end
    end
  end
end
