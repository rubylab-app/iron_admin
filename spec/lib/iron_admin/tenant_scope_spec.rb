# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::TenantScope do
  describe ".apply" do
    it "returns the relation unchanged when no tenant scope is configured" do
      relation = License.all

      expect(described_class.apply(relation)).to be(relation)
    end

    it "returns the relation produced by the configured tenant scope" do
      user = create(:user)
      IronAdmin.configure do |config|
        config.tenant_scope { |scope| scope.where(user_id: user.id) }
      end

      expect(described_class.apply(License.all).to_sql).to eq(License.where(user_id: user.id).to_sql)
    end
  end

  describe ".configured?" do
    it "is false when no tenant scope is configured" do
      expect(described_class.configured?).to be(false)
    end

    it "is true when a tenant scope block is configured" do
      IronAdmin.configure { |config| config.tenant_scope { |scope| scope } }

      expect(described_class.configured?).to be(true)
    end
  end
end
