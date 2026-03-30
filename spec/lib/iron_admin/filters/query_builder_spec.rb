# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Filters::QueryBuilder do
  subject(:result) { described_class.call(base_scope, filter, params_hash) }

  let(:base_scope) { User.all }
  let(:filter) { { name: :name, type: :string } }
  let(:params_hash) { { "op" => op, "value" => value } }
  let(:op) { "contains" }
  let(:value) { "test" }

  describe ".call" do
    context "when value is blank" do
      let(:value) { "" }

      it "returns the scope unchanged" do
        expect(result.to_sql).to eq(base_scope.to_sql)
      end
    end

    context "when value is nil" do
      let(:value) { nil }

      it "returns the scope unchanged" do
        expect(result.to_sql).to eq(base_scope.to_sql)
      end
    end

    context "when filter type is unknown" do
      let(:filter) { { name: :name, type: :unknown } }

      it "returns the scope unchanged" do
        expect(result.to_sql).to eq(base_scope.to_sql)
      end
    end
  end

  context "with string filter type" do
    let(:filter) { { name: :name, type: :string } }

    context 'with "contains" operator' do
      let(:op) { "contains" }
      let(:value) { "Acme" }

      before do
        create(:user, name: "Alice Acme")
        create(:user, name: "Bob Builder")
      end

      it "matches records with value anywhere in column" do
        expect(result.pluck(:name)).to eq(["Alice Acme"])
      end

      context "when value has leading/trailing whitespace" do
        let(:value) { "  Acme  " }

        it "strips whitespace before matching" do
          expect(result.pluck(:name)).to eq(["Alice Acme"])
        end
      end
    end

    context 'with "equals" operator' do
      let(:op) { "equals" }
      let(:value) { "Alice" }

      before do
        create(:user, name: "Alice")
        create(:user, name: "Alice Acme")
      end

      it "matches only the exact value" do
        expect(result.pluck(:name)).to eq(["Alice"])
      end
    end

    context 'with "starts_with" operator' do
      let(:op) { "starts_with" }
      let(:value) { "Alice" }

      before do
        create(:user, name: "Alice Acme")
        create(:user, name: "Bob Alice")
      end

      it "matches records where column starts with value" do
        expect(result.pluck(:name)).to eq(["Alice Acme"])
      end
    end

    context 'with "ends_with" operator' do
      let(:op) { "ends_with" }
      let(:value) { "Acme" }

      before do
        create(:user, name: "Alice Acme")
        create(:user, name: "Acme Bob")
      end

      it "matches records where column ends with value" do
        expect(result.pluck(:name)).to eq(["Alice Acme"])
      end
    end

    context "with invalid operator" do
      let(:op) { "drop_table" }

      it "returns scope unchanged" do
        create(:user, name: "Alice")
        expect(result.to_sql).to eq(base_scope.to_sql)
      end
    end
  end

  context "with number filter type" do
    let(:base_scope) { License.all }
    let(:user) { create(:user) }
    let(:filter) { { name: :max_devices, type: :number } }

    context 'with "equals" operator' do
      let(:op) { "equals" }
      let(:value) { "5" }

      before do
        create(:license, user: user, max_devices: 5)
        create(:license, user: user, max_devices: 10)
      end

      it "matches exact numeric value" do
        expect(result.pluck(:max_devices)).to eq([5])
      end
    end

    context 'with "greater_than" operator' do
      let(:op) { "greater_than" }
      let(:value) { "7" }

      before do
        create(:license, user: user, max_devices: 5)
        create(:license, user: user, max_devices: 10)
      end

      it "matches values above the threshold" do
        expect(result.pluck(:max_devices)).to eq([10])
      end
    end

    context 'with "less_than" operator' do
      let(:op) { "less_than" }
      let(:value) { "7" }

      before do
        create(:license, user: user, max_devices: 5)
        create(:license, user: user, max_devices: 10)
      end

      it "matches values below the threshold" do
        expect(result.pluck(:max_devices)).to eq([5])
      end
    end

    context 'with "between" operator' do
      let(:op) { "between" }
      let(:value) { "5" }
      let(:params_hash) { { "op" => op, "value" => value, "value_2" => upper_value } }
      let(:upper_value) { "10" }

      before do
        create(:license, user: user, max_devices: 1)
        create(:license, user: user, max_devices: 5)
        create(:license, user: user, max_devices: 10)
        create(:license, user: user, max_devices: 20)
      end

      it "matches values in the inclusive range" do
        expect(result.pluck(:max_devices)).to contain_exactly(5, 10)
      end

      context "when upper bound is blank" do
        let(:upper_value) { "" }

        it "returns scope unchanged" do
          expect(result.to_sql).to eq(base_scope.to_sql)
        end
      end
    end

    context "with non-numeric value" do
      let(:op) { "equals" }
      let(:value) { "abc" }

      it "returns scope unchanged" do
        create(:license, user: user, max_devices: 5)
        expect(result.to_sql).to eq(base_scope.to_sql)
      end
    end

    context "with decimal column" do
      let(:base_scope) { Profile.all }
      let(:filter) { { name: :hourly_rate, type: :number } }
      let(:op) { "greater_than" }
      let(:value) { "75.0" }

      it "handles float values correctly" do
        create(:profile, user: user, hourly_rate: 50.00)
        create(:profile, user: create(:user), hourly_rate: 100.50)

        expect(result.pluck(:hourly_rate).map(&:to_f)).to eq([100.50])
      end
    end

    context "with invalid operator" do
      let(:op) { "drop_table" }
      let(:value) { "5" }

      it "returns scope unchanged" do
        create(:license, user: user, max_devices: 5)
        expect(result.to_sql).to eq(base_scope.to_sql)
      end
    end
  end

  context "with LIKE wildcard characters in value" do
    let(:filter) { { name: :name, type: :string } }
    let(:op) { "contains" }

    context "when value contains percent character" do
      let(:value) { "100%" }

      it "escapes the percent and matches literally" do
        create(:user, name: "100% Complete")
        create(:user, name: "Alice")

        expect(result.pluck(:name)).to eq(["100% Complete"])
      end
    end

    context "when value contains underscore character" do
      let(:value) { "r_n" }

      it "escapes the underscore and matches literally" do
        create(:user, name: "user_name")
        create(:user, name: "username")

        expect(result.pluck(:name)).to eq(["user_name"])
      end
    end
  end

  context "with SQL-sensitive input" do
    let(:filter) { { name: :name, type: :string } }
    let(:value) { "Alice" }

    it "quotes the table name in generated SQL" do
      create(:user, name: "Alice")
      expect(result.to_sql).to include('"users"')
    end
  end
end
