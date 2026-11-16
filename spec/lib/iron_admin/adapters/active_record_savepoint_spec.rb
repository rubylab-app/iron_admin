# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Adapters::ActiveRecord do
  describe "#savepoint" do
    let(:adapter) do
      Class.new(IronAdmin::Resource) do
        def self.name = "SavepointLicenseResource"
        def self.resource_name = "savepoint_licenses"

        self.model_class_override = License
      end.adapter
    end

    it "rolls the savepoint back and keeps the license created in the outer transaction" do
      user = create(:user)
      outer = nil

      License.transaction do
        outer = create(:license, user:, license_key: "SAVE-OUTER")
        adapter.savepoint do
          adapter.wrap_rollback do
            create(:license, user:, license_key: "SAVE-INNER")
            raise IronAdmin::Rollback
          end
        end
      end

      expect(License.find_by(license_key: "SAVE-OUTER")).to eq(outer)
      expect(License.find_by(license_key: "SAVE-INNER")).to be_nil
    end
  end
end
