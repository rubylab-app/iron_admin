require "rails_helper"

RSpec.describe IronAdmin::Policy do
  describe "with allow rules" do
    let(:policy) do
      described_class.new do
        allow :index, :show
        allow :create, :update, if: ->(user) { user == :admin }
        allow :destroy, if: ->(user) { user == :super_admin }
      end
    end

    it "allows unrestricted actions" do
      expect(policy.allowed?(:index, :user)).to be(true)
      expect(policy.allowed?(:show, :user)).to be(true)
    end

    it "checks conditional allows" do
      expect(policy.allowed?(:create, :admin)).to be(true)
      expect(policy.allowed?(:create, :user)).to be(false)
    end

    it "restricts destroy" do
      expect(policy.allowed?(:destroy, :super_admin)).to be(true)
      expect(policy.allowed?(:destroy, :admin)).to be(false)
    end
  end

  describe "#action_allowed?" do
    context "when custom action is not in allow rules" do
      subject(:policy) do
        described_class.new do
          allow :read
          allow :create, :update, if: ->(user) { user == :admin }
        end
      end

      it "allows custom actions by default" do
        expect(policy.action_allowed?(:archive, :user)).to be(true)
      end

      it "allows bulk actions by default" do
        expect(policy.action_allowed?(:bulk_archive, :user)).to be(true)
      end
    end

    context "when custom action has a conditional allow rule" do
      subject(:policy) do
        described_class.new do
          allow :read
          allow :archive, if: ->(user) { user == :admin }
        end
      end

      it "allows when condition is met" do
        expect(policy.action_allowed?(:archive, :admin)).to be(true)
      end

      it "denies when condition is not met" do
        expect(policy.action_allowed?(:archive, :user)).to be(false)
      end

      it "handles string action names by normalizing to symbol" do
        expect(policy.action_allowed?("archive", :admin)).to be(true)
        expect(policy.action_allowed?("archive", :user)).to be(false)
      end
    end

    context "when custom action has an unconditional allow rule" do
      subject(:policy) do
        described_class.new do
          allow :read
          allow :archive
        end
      end

      it "allows the action for all users" do
        expect(policy.action_allowed?(:archive, :anyone)).to be(true)
      end
    end

    context "when no policy is configured" do
      subject(:policy) { described_class.new }

      it "allows all custom actions" do
        expect(policy.action_allowed?(:archive, :anyone)).to be(true)
      end
    end
  end

  describe "without policy" do
    let(:policy) { described_class.new }

    it "allows everything by default" do
      expect(policy.allowed?(:destroy, :anyone)).to be(true)
    end
  end
end
