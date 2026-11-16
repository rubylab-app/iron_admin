# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Adapters::Base do
  describe "IronAdmin::Adapters#build_in" do
    it "delegates to build on Base" do
      adapter_class = Class.new(IronAdmin::Adapters::Base) do
        def build(attrs = {})
          [:built, attrs]
        end
      end

      built = adapter_class.new(License).build_in(:unused, { license_key: "K-1" })

      expect(built).to eq([:built, { license_key: "K-1" }])
    end

    it "assigns equality conditions that are attributes of the model" do
      user = create(:user)
      adapter = IronAdmin::Adapters::ActiveRecord.new(License)
      scope = License.where(user_id: user.id, status: :active)

      record = adapter.build_in(scope, { license_key: "K-1" })

      expect(record.user_id).to eq(user.id)
      expect(record.status.to_s).to eq("active")
      expect(record.license_key).to eq("K-1")
    end

    it "ignores equality conditions that are not attributes of the model" do
      user = create(:user)
      adapter = IronAdmin::Adapters::ActiveRecord.new(License)
      scope = instance_double(
        ActiveRecord::Relation,
        where_values_hash: { "user_id" => user.id, "active" => true }
      )

      record = adapter.build_in(scope, { license_key: "K-2" })

      expect(record).to be_a(License)
      expect(record.user_id).to eq(user.id)
      expect(record.license_key).to eq("K-2")
    end
  end
end
