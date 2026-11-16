# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::AssignableRecordsHelper, type: :helper do
  describe "#assignable_records" do
    it "returns every tag when no tenant scope is configured" do
      Tag.create!(name: "visible-tag")
      Tag.create!(name: "other-tag")

      names = helper.assignable_records(Tag).map(&:name)

      expect(names).to include("visible-tag", "other-tag")
    end

    it "returns only the tags the tenant scope keeps" do
      Tag.create!(name: "visible-tag")
      Tag.create!(name: "other-tag")
      IronAdmin.configure do |c|
        c.tenant_scope { |scope| scope.model == Tag ? scope.where(name: "visible-tag") : scope }
      end

      names = helper.assignable_records(Tag).map(&:name)

      expect(names).to include("visible-tag")
      expect(names).not_to include("other-tag")
    end
  end

  describe "#association_value_key" do
    it "is the foreign key target of a reflected association" do
      expect(helper.association_value_key(License, :user)).to eq(:id)
    end

    it "is :id when the model does not reflect associations" do
      expect(helper.association_value_key(Object, :anything)).to eq(:id)
    end
  end
end
