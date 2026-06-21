# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Import::TypeCaster do
  subject(:caster) { described_class.new }

  it "casts boolean values" do
    field = IronAdmin::Field.new(:active, type: :boolean)

    expect(caster.cast("yes", field)).to be(true)
    expect(caster.cast("0", field)).to be(false)
  end

  it "casts JSON values" do
    field = IronAdmin::Field.new(:preferences, type: :json)

    expect(caster.cast(%({"tier":"gold"}), field)).to eq("tier" => "gold")
  end

  it "casts numeric values" do
    expect(caster.cast("42", IronAdmin::Field.new(:age, type: :integer))).to eq(42)
    expect(caster.cast("12.5", IronAdmin::Field.new(:ratio, type: :float))).to eq(12.5)
    expect(caster.cast("19.99", IronAdmin::Field.new(:price, type: :decimal))).to eq(BigDecimal("19.99"))
    expect(caster.cast("7", IronAdmin::Field.new(:score, type: :number))).to eq(7)
    expect(caster.cast("7.5", IronAdmin::Field.new(:score, type: :number))).to eq(7.5)
  end

  it "casts dates and datetimes" do
    date_field = IronAdmin::Field.new(:starts_on, type: :date)
    datetime_field = IronAdmin::Field.new(:expires_at, type: :datetime)

    expect(caster.cast("2026-06-21", date_field)).to eq(Date.new(2026, 6, 21))
    expect(caster.cast("2026-06-21T10:30:00Z", datetime_field)).to eq(Time.zone.parse("2026-06-21T10:30:00Z"))
  end

  it "normalizes blank values to nil" do
    field = IronAdmin::Field.new(:name, type: :string)

    expect(caster.cast("  ", field)).to be_nil
  end
end
