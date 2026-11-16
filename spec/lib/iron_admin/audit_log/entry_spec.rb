# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::AuditLog::Entry do
  describe "#initialize" do
    it "sets attributes from hash" do
      entry = described_class.new(
        user: "admin",
        action: :create,
        resource: "User",
        record_id: 1,
        changes: { name: %w[old new] },
        ip_address: "127.0.0.1"
      )

      expect(entry.user).to eq("admin")
      expect(entry.action).to eq(:create)
      expect(entry.resource).to eq("User")
      expect(entry.record_id).to eq(1)
      expect(entry.changes).to eq({ name: %w[old new] })
      expect(entry.ip_address).to eq("127.0.0.1")
    end

    it "sets timestamp to current time when not provided" do
      before_time = Time.current
      entry = described_class.new(action: :create)
      after_time = Time.current

      expect(entry.timestamp).to be >= before_time
      expect(entry.timestamp).to be <= after_time
    end

    it "uses provided timestamp when given" do
      custom_time = 1.hour.ago
      entry = described_class.new(timestamp: custom_time)
      expect(entry.timestamp).to eq(custom_time)
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      timestamp = Time.current
      entry = described_class.new(
        user: "admin",
        action: :create,
        resource: "User",
        record_id: 1,
        changes: { name: %w[old new] },
        ip_address: "127.0.0.1",
        tenant_key: "42",
        timestamp: timestamp
      )

      expect(entry.to_h).to eq({
                                 user: "admin",
                                 action: :create,
                                 resource: "User",
                                 record_id: 1,
                                 changes: { name: %w[old new] },
                                 ip_address: "127.0.0.1",
                                 tenant_key: "42",
                                 timestamp: timestamp,
                               })
    end
  end
end
