# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Filters::ActiveRecordQueryBuilder do
  describe ".call" do
    context "with string filter" do
      let(:filter) { { name: :name, type: :string } }

      it "applies contains operator" do
        create(:user, name: "Alice Smith")
        create(:user, name: "Bob Jones")
        result = described_class.call(User.all, filter, "op" => "contains", "value" => "Alice")
        expect(result.count).to eq(1)
      end

      it "applies equals operator" do
        create(:user, name: "Alice")
        create(:user, name: "Alice Smith")
        result = described_class.call(User.all, filter, "op" => "equals", "value" => "Alice")
        expect(result.count).to eq(1)
        expect(result.first.name).to eq("Alice")
      end

      it "applies starts_with operator" do
        create(:user, name: "Alice Smith")
        create(:user, name: "Bob Alice")
        result = described_class.call(User.all, filter, "op" => "starts_with", "value" => "Alice")
        expect(result.count).to eq(1)
      end

      it "applies ends_with operator" do
        create(:user, name: "Smith Alice")
        create(:user, name: "Alice Smith")
        result = described_class.call(User.all, filter, "op" => "ends_with", "value" => "Alice")
        expect(result.count).to eq(1)
        expect(result.first.name).to eq("Smith Alice")
      end

      it "returns unmodified scope for blank value" do
        create_list(:user, 2)
        result = described_class.call(User.all, filter, "op" => "contains", "value" => "")
        expect(result.count).to eq(2)
      end

      it "returns unmodified scope for invalid operator" do
        create_list(:user, 2)
        result = described_class.call(User.all, filter, "op" => "invalid", "value" => "test")
        expect(result.count).to eq(2)
      end
    end

    context "with number filter" do
      subject(:filter) { { name: :id, type: :number } }

      it "applies equals operator" do
        user = create(:user)
        result = described_class.call(User.all, filter, "op" => "equals", "value" => user.id.to_s)
        expect(result.count).to eq(1)
      end

      it "applies greater_than operator" do
        users = create_list(:user, 3)
        result = described_class.call(User.all, filter, "op" => "greater_than", "value" => users.first.id.to_s)
        expect(result.count).to eq(2)
      end

      it "applies less_than operator" do
        users = create_list(:user, 3)
        result = described_class.call(User.all, filter, "op" => "less_than", "value" => users.last.id.to_s)
        expect(result.count).to eq(2)
      end

      it "applies between operator" do
        users = create_list(:user, 3)
        result = described_class.call(
          User.all, filter,
          "op" => "between", "value" => users.first.id.to_s, "value_2" => users.last.id.to_s
        )
        expect(result.count).to eq(3)
      end

      it "returns unmodified scope for non-numeric value" do
        create_list(:user, 2)
        result = described_class.call(User.all, filter, "op" => "equals", "value" => "abc")
        expect(result.count).to eq(2)
      end
    end
  end
end
