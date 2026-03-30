# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Filters::QueryBuilder do
  let(:base_scope) { User.all }

  describe ".call" do
    it "returns the scope unchanged when value is blank" do
      filter = { name: :name, type: :string }
      result = described_class.call(base_scope, filter, { "op" => "contains", "value" => "" })

      expect(result.to_sql).to eq(base_scope.to_sql)
    end

    it "returns the scope unchanged when value is nil" do
      filter = { name: :name, type: :string }
      result = described_class.call(base_scope, filter, { "op" => "contains", "value" => nil })

      expect(result.to_sql).to eq(base_scope.to_sql)
    end

    it "returns the scope unchanged for unknown filter type" do
      filter = { name: :name, type: :unknown }
      result = described_class.call(base_scope, filter, { "op" => "contains", "value" => "test" })

      expect(result.to_sql).to eq(base_scope.to_sql)
    end
  end

  describe "string operators" do
    let(:filter) { { name: :name, type: :string } }

    describe "contains" do
      it "matches records with value anywhere in column" do
        create(:user, name: "Alice Acme")
        create(:user, name: "Bob Builder")

        result = described_class.call(base_scope, filter, { "op" => "contains", "value" => "Acme" })

        expect(result.pluck(:name)).to eq(["Alice Acme"])
      end

      it "strips whitespace from value" do
        create(:user, name: "Alice Acme")

        result = described_class.call(base_scope, filter, { "op" => "contains", "value" => "  Acme  " })

        expect(result.pluck(:name)).to eq(["Alice Acme"])
      end
    end

    describe "equals" do
      it "matches only the exact value" do
        create(:user, name: "Alice")
        create(:user, name: "Alice Acme")

        result = described_class.call(base_scope, filter, { "op" => "equals", "value" => "Alice" })

        expect(result.pluck(:name)).to eq(["Alice"])
      end
    end

    describe "starts_with" do
      it "matches records where column starts with value" do
        create(:user, name: "Alice Acme")
        create(:user, name: "Bob Alice")

        result = described_class.call(base_scope, filter, { "op" => "starts_with", "value" => "Alice" })

        expect(result.pluck(:name)).to eq(["Alice Acme"])
      end
    end

    describe "ends_with" do
      it "matches records where column ends with value" do
        create(:user, name: "Alice Acme")
        create(:user, name: "Acme Bob")

        result = described_class.call(base_scope, filter, { "op" => "ends_with", "value" => "Acme" })

        expect(result.pluck(:name)).to eq(["Alice Acme"])
      end
    end

    context "with invalid operator" do
      it "returns scope unchanged" do
        create(:user, name: "Alice")

        result = described_class.call(base_scope, filter, { "op" => "drop_table", "value" => "test" })

        expect(result.to_sql).to eq(base_scope.to_sql)
      end
    end
  end

  describe "number operators" do
    let(:base_scope) { License.all }
    let(:user) { create(:user) }
    let(:filter) { { name: :max_devices, type: :number } }

    describe "equals" do
      it "matches exact numeric value" do
        create(:license, user: user, max_devices: 5)
        create(:license, user: user, max_devices: 10)

        result = described_class.call(base_scope, filter, { "op" => "equals", "value" => "5" })

        expect(result.pluck(:max_devices)).to eq([5])
      end
    end

    describe "greater_than" do
      it "matches values greater than the given number" do
        create(:license, user: user, max_devices: 5)
        create(:license, user: user, max_devices: 10)

        result = described_class.call(base_scope, filter, { "op" => "greater_than", "value" => "7" })

        expect(result.pluck(:max_devices)).to eq([10])
      end
    end

    describe "less_than" do
      it "matches values less than the given number" do
        create(:license, user: user, max_devices: 5)
        create(:license, user: user, max_devices: 10)

        result = described_class.call(base_scope, filter, { "op" => "less_than", "value" => "7" })

        expect(result.pluck(:max_devices)).to eq([5])
      end
    end

    describe "between" do
      it "matches values in the inclusive range" do
        create(:license, user: user, max_devices: 1)
        create(:license, user: user, max_devices: 5)
        create(:license, user: user, max_devices: 10)
        create(:license, user: user, max_devices: 20)

        result = described_class.call(base_scope, filter,
                                      { "op" => "between", "value" => "5", "value_2" => "10" })

        expect(result.pluck(:max_devices)).to contain_exactly(5, 10)
      end

      it "returns scope unchanged when value_2 is blank" do
        create(:license, user: user, max_devices: 5)

        result = described_class.call(base_scope, filter,
                                      { "op" => "between", "value" => "5", "value_2" => "" })

        expect(result.to_sql).to eq(base_scope.to_sql)
      end
    end

    context "with non-numeric value" do
      it "returns scope unchanged" do
        create(:license, user: user, max_devices: 5)

        result = described_class.call(base_scope, filter, { "op" => "equals", "value" => "abc" })

        expect(result.to_sql).to eq(base_scope.to_sql)
      end
    end

    context "with float values" do
      let(:base_scope) { Profile.all }
      let(:filter) { { name: :hourly_rate, type: :number } }

      it "handles decimal values" do
        create(:profile, user: user, hourly_rate: 50.00)
        create(:profile, user: create(:user), hourly_rate: 100.50)

        result = described_class.call(base_scope, filter, { "op" => "greater_than", "value" => "75.0" })

        expect(result.pluck(:hourly_rate).map(&:to_f)).to eq([100.50])
      end
    end

    context "with invalid operator" do
      it "returns scope unchanged" do
        create(:license, user: user, max_devices: 5)

        result = described_class.call(base_scope, filter, { "op" => "drop_table", "value" => "5" })

        expect(result.to_sql).to eq(base_scope.to_sql)
      end
    end
  end

  describe "LIKE wildcard escaping" do
    let(:filter) { { name: :name, type: :string } }

    it "escapes percent characters in value" do
      create(:user, name: "100% Complete")
      create(:user, name: "Alice")

      result = described_class.call(base_scope, filter, { "op" => "contains", "value" => "100%" })

      expect(result.pluck(:name)).to eq(["100% Complete"])
    end

    it "escapes underscore characters in value" do
      create(:user, name: "user_name")
      create(:user, name: "username")

      result = described_class.call(base_scope, filter, { "op" => "contains", "value" => "r_n" })

      expect(result.pluck(:name)).to eq(["user_name"])
    end
  end

  describe "SQL safety" do
    let(:filter) { { name: :name, type: :string } }

    it "uses quoted table name in the query" do
      create(:user, name: "Alice")

      result = described_class.call(base_scope, filter, { "op" => "contains", "value" => "Alice" })

      expect(result.to_sql).to include('"users"')
    end
  end
end
