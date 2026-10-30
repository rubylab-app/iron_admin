# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::ScopeCounts do
  subject(:counts) do
    described_class.new(resource: resource, adapter: adapter, relation_for: relation_for).to_h
  end

  let(:adapter) { double("adapter") }
  let(:relation_for) { double("relation_for") }
  let(:enabled) { true }
  let(:scopes) do
    [
      { name: :open, scope: :open_body },
      { name: :closed, scope: :closed_body },
    ]
  end
  let(:resource) { double("resource", scope_counts_enabled?: enabled, all_scopes: scopes) }

  describe "#to_h" do
    it "counts each scope through exact_count and keeps zero" do
      allow(relation_for).to receive(:call).with(:open_body).and_return(:open_relation)
      allow(relation_for).to receive(:call).with(:closed_body).and_return(:closed_relation)
      allow(adapter).to receive(:exact_count).with(:open_relation).and_return(3)
      allow(adapter).to receive(:exact_count).with(:closed_relation).and_return(0)

      expect(counts).to eq("open" => 3, "closed" => 0)
    end

    it "omits a scope whose count is unknown" do
      allow(relation_for).to receive(:call).and_return(:relation)
      allow(adapter).to receive(:exact_count).and_return(nil)

      expect(counts).to eq({})
    end

    context "when a scope sets count: false" do
      let(:scopes) do
        [
          { name: :open, scope: :open_body },
          { name: :closed, scope: :closed_body, count: false },
        ]
      end

      it "returns the scopes it counted" do
        allow(relation_for).to receive(:call).with(:open_body).and_return(:open_relation)
        allow(adapter).to receive(:exact_count).with(:open_relation).and_return(3)

        expect(counts).to eq("open" => 3)
      end

      it "builds only that scope's relation" do
        allow(relation_for).to receive(:call).with(:open_body).and_return(:open_relation)
        allow(adapter).to receive(:exact_count).with(:open_relation).and_return(3)

        counts

        expect(relation_for).to have_received(:call).with(:open_body).once
      end

      it "asks the adapter only for that scope" do
        allow(relation_for).to receive(:call).with(:open_body).and_return(:open_relation)
        allow(adapter).to receive(:exact_count).with(:open_relation).and_return(3)

        counts

        expect(adapter).to have_received(:exact_count).with(:open_relation).once
      end
    end

    context "when the feature is off" do
      let(:enabled) { false }

      it "returns an empty hash" do
        allow(relation_for).to receive(:call)
        allow(adapter).to receive(:exact_count)

        expect(counts).to eq({})
      end

      it "builds no relation" do
        allow(relation_for).to receive(:call)
        allow(adapter).to receive(:exact_count)

        counts

        expect(relation_for).not_to have_received(:call)
      end

      it "does not ask the adapter" do
        allow(relation_for).to receive(:call)
        allow(adapter).to receive(:exact_count)

        counts

        expect(adapter).not_to have_received(:exact_count)
      end
    end

    context "when the relation is nil" do
      before do
        allow(relation_for).to receive(:call).with(:open_body).and_return(nil)
        allow(relation_for).to receive(:call).with(:closed_body).and_return(:closed_relation)
        allow(adapter).to receive(:exact_count).with(:closed_relation).and_return(2)
      end

      it "omits that scope" do
        expect(counts).to eq("closed" => 2)
      end

      it "does not pass nil to exact_count" do
        counts

        expect(adapter).not_to have_received(:exact_count).with(nil)
      end
    end

    context "when the relation is false" do
      before do
        allow(relation_for).to receive(:call).and_return(false)
        allow(adapter).to receive(:exact_count)
      end

      it "returns an empty hash" do
        expect(counts).to eq({})
      end

      it "does not ask the adapter" do
        counts

        expect(adapter).not_to have_received(:exact_count)
      end
    end

    context "when exact_count raises NotImplementedError" do
      before do
        allow(relation_for).to receive(:call).with(:open_body).and_return(:open_relation)
        allow(relation_for).to receive(:call).with(:closed_body).and_return(:closed_relation)
        allow(adapter).to receive(:exact_count).with(:open_relation).and_return(3)
        allow(adapter).to receive(:exact_count).with(:closed_relation).and_raise(NotImplementedError, "count")
        allow(Rails.logger).to receive(:error)
      end

      it "keeps the other counts" do
        expect(counts).to eq("open" => 3)
      end

      it "logs the error" do
        counts

        expect(Rails.logger).to have_received(:error).with(
          a_string_starting_with("[IronAdmin] NotImplementedError: count")
        )
      end
    end

    context "when one scope raises" do
      before do
        allow(relation_for).to receive(:call).with(:open_body).and_return(:open_relation)
        allow(relation_for).to receive(:call).with(:closed_body).and_raise(RuntimeError, "count failed")
        allow(adapter).to receive(:exact_count).with(:open_relation).and_return(3)
        allow(Rails.logger).to receive(:error)
      end

      it "keeps the other counts" do
        expect(counts).to eq("open" => 3)
      end

      it "logs the error" do
        counts

        expect(Rails.logger).to have_received(:error).with(
          a_string_starting_with("[IronAdmin] RuntimeError: count failed")
        )
      end
    end
  end

  describe ".label" do
    let(:scope) { { name: :active } }

    it "appends the count" do
      expect(described_class.label(scope, { "active" => 12 })).to eq("Active (12)")
    end

    it "appends zero" do
      expect(described_class.label(scope, { "active" => 0 })).to eq("Active (0)")
    end

    it "reads a symbol key" do
      expect(described_class.label(scope, { active: 4 })).to eq("Active (4)")
    end

    it "omits a missing count" do
      expect(described_class.label(scope, {})).to eq("Active")
    end

    it "treats a nil hash as no counts" do
      expect(described_class.label(scope, nil)).to eq("Active")
    end
  end
end
