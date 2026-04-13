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

  describe "with deny rules" do
    context "when deny is unconditional" do
      subject(:policy) do
        described_class.new do
          allow :read, :create, :update, :destroy
          deny :destroy
        end
      end

      it "denies the action for all users" do
        expect(policy.allowed?(:destroy, :admin)).to be(false)
        expect(policy.allowed?(:destroy, :super_admin)).to be(false)
      end

      it "does not affect other allowed actions" do
        expect(policy.allowed?(:read, :user)).to be(true)
        expect(policy.allowed?(:create, :user)).to be(true)
        expect(policy.allowed?(:update, :user)).to be(true)
      end
    end

    context "when deny is conditional" do
      subject(:policy) do
        described_class.new do
          allow :read, :create, :update, :destroy
          deny :destroy, if: ->(user) { user != :super_admin }
        end
      end

      it "denies the action when condition is met" do
        expect(policy.allowed?(:destroy, :admin)).to be(false)
      end

      it "allows the action when condition is not met" do
        expect(policy.allowed?(:destroy, :super_admin)).to be(true)
      end
    end

    context "when deny overrides allow" do
      subject(:policy) do
        described_class.new do
          allow :destroy, if: ->(user) { user == :admin }
          deny :destroy
        end
      end

      it "deny takes precedence over allow" do
        expect(policy.allowed?(:destroy, :admin)).to be(false)
      end
    end

    context "with deny on custom actions via action_allowed?" do
      subject(:policy) do
        described_class.new do
          allow :read
          allow :archive
          deny :archive, if: ->(user) { user != :admin }
        end
      end

      it "denies the custom action when condition is met" do
        expect(policy.action_allowed?(:archive, :user)).to be(false)
      end

      it "allows the custom action when condition is not met" do
        expect(policy.action_allowed?(:archive, :admin)).to be(true)
      end
    end

    context "with deny and action aliases" do
      subject(:policy) do
        described_class.new do
          allow :read, :create, :update, :destroy
          deny :read
        end
      end

      it "deny :read also denies :show" do
        expect(policy.allowed?(:show, :user)).to be(false)
      end

      it "deny :read also denies :index" do
        expect(policy.allowed?(:index, :user)).to be(false)
      end
    end

    context "with deny on alias that affects base action" do
      subject(:policy) do
        described_class.new do
          allow :read, :create, :update, :destroy
          deny :show
        end
      end

      it "deny :show also denies :read" do
        expect(policy.allowed?(:read, :user)).to be(false)
      end
    end

    context "with multiple deny rules" do
      subject(:policy) do
        described_class.new do
          allow :read, :create, :update, :destroy
          deny :create, :destroy
        end
      end

      it "denies all specified actions" do
        expect(policy.allowed?(:create, :admin)).to be(false)
        expect(policy.allowed?(:destroy, :admin)).to be(false)
      end

      it "allows non-denied actions" do
        expect(policy.allowed?(:read, :admin)).to be(true)
        expect(policy.allowed?(:update, :admin)).to be(true)
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
