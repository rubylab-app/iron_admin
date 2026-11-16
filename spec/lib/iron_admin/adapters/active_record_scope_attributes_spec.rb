# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Adapters::ActiveRecord do
  describe "#scope_attributes" do
    it "uses the adapter model when the scope does not expose klass" do
      user = create(:user)
      adapter = described_class.new(License)
      scope = instance_double(
        ActiveRecord::Relation,
        where_values_hash: { "user_id" => user.id, "active" => true, "id" => [user.id] }
      )

      expect(adapter.scope_attributes(scope)).to eq("user_id" => user.id)
    end
  end
end
