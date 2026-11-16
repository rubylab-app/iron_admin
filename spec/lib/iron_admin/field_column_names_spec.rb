# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Field do
  describe "#column_names" do
    it "returns the field name for an ordinary column" do
      field = described_class.new(:license_key, type: :text)

      expect(field.column_names).to eq(%i[license_key])
    end

    it "returns the association name and foreign key for belongs_to" do
      field = described_class.new(:user, type: :belongs_to, foreign_key: "user_id")

      expect(field.column_names).to eq(%i[user user_id])
    end

    it "omits a belongs_to foreign key that was not configured" do
      field = described_class.new(:user, type: :belongs_to)

      expect(field.column_names).to eq(%i[user])
    end

    it "returns the type and id columns for polymorphic belongs_to" do
      field = described_class.new(
        :notable,
        type: :polymorphic_belongs_to,
        type_column: :notable_type,
        id_column: :notable_id
      )

      expect(field.column_names).to eq(%i[notable notable_type notable_id])
    end

    it "omits polymorphic columns that were not configured" do
      field = described_class.new(:notable, type: :polymorphic_belongs_to, type_column: :notable_type)

      expect(field.column_names).to eq(%i[notable notable_type])
    end
  end
end
