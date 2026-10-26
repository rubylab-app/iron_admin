# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Import::ImportPreview do
  subject(:preview) { described_class.new(total_rows: 1, headers: [], mapping: {}, rows: [], errors: []) }

  describe "#cell_text" do
    def cell_text_for(value)
      preview.cell_text(IronAdmin::Import::Row.new(number: 1, attributes: { value: value }, errors: []), :value)
    end

    context "with a date" do
      it "uses the show page's default date format" do
        expect(cell_text_for(Date.new(2026, 10, 20))).to eq("Oct 20, 2026")
      end
    end

    context "with a time" do
      it "uses the show page's default datetime format" do
        expect(cell_text_for(Time.zone.parse("2026-10-20 15:05:00"))).to eq("Oct 20, 2026 at 3:05 PM")
      end
    end

    context "without the column's field" do
      it "renders the value as plain text" do
        expect(cell_text_for(true)).to eq("true")
      end
    end

    context "when the active locale has no date formats" do
      around do |example|
        original = I18n.available_locales
        I18n.available_locales = original + [:xx]
        I18n.with_locale(:xx) { example.run }
      ensure
        I18n.available_locales = original
      end

      it "formats the date without a locale lookup" do
        expect(cell_text_for(Date.new(2026, 10, 20))).to eq("Oct 20, 2026")
      end

      it "labels a boolean in English" do
        expect(field_cell_text(true, IronAdmin::Field.new(:value, type: :boolean))).to eq("Yes")
      end
    end

    # With the column's field: the show page's formatting of that field (FieldDisplayHelper), as plain text.
    context "with a boolean field" do
      let(:field) { IronAdmin::Field.new(:value, type: :boolean) }

      it "labels true as Yes" do
        expect(field_cell_text(true, field)).to eq("Yes")
      end

      it "labels false as No" do
        expect(field_cell_text(false, field)).to eq("No")
      end

      it "leaves a blank cell empty instead of reading it as No" do
        expect(field_cell_text(nil, field)).to eq("")
      end

      context "when the active locale translates the labels" do
        around do |example|
          original = I18n.available_locales
          I18n.available_locales = original + [:xy]
          I18n.backend.store_translations(:xy, iron_admin: { fields: { boolean_true: "Sí" } })
          I18n.with_locale(:xy) { example.run }
        ensure
          I18n.available_locales = original
          I18n.backend.reload!
        end

        it "uses the locale's label" do
          expect(field_cell_text(true, field)).to eq("Sí")
        end
      end
    end

    context "with a date field that sets a format" do
      it "uses the field's format" do
        field = IronAdmin::Field.new(:value, type: :date, format: "%d/%m/%Y")

        expect(field_cell_text(Date.new(2026, 10, 20), field)).to eq("20/10/2026")
      end
    end

    context "with a datetime field that sets a format" do
      it "uses the field's format" do
        field = IronAdmin::Field.new(:value, type: :datetime, format: "%Y-%m-%d %H:%M")

        expect(field_cell_text(Time.zone.parse("2026-10-20 15:05:00"), field)).to eq("2026-10-20 15:05")
      end
    end

    context "with a currency field" do
      it "adds the symbol, the delimiters and two decimals" do
        expect(field_cell_text("1234.5", IronAdmin::Field.new(:value, type: :currency))).to eq("$1,234.50")
      end

      it "uses the field's symbol and precision" do
        field = IronAdmin::Field.new(:value, type: :currency, symbol: "€", precision: 0)

        expect(field_cell_text(BigDecimal("1234.6"), field)).to eq("€1,235")
      end

      it "shows a value that is not a number as it is" do
        expect(field_cell_text("n/a", IronAdmin::Field.new(:value, type: :currency))).to eq("n/a")
      end
    end

    context "with a badge field" do
      it "humanizes the value" do
        expect(field_cell_text("in_review", IronAdmin::Field.new(:value, type: :badge))).to eq("In review")
      end
    end

    context "with a password field" do
      it "masks the value" do
        expect(field_cell_text("s3cret", IronAdmin::Field.new(:value, type: :password))).to eq("\u2022" * 8)
      end
    end

    context "with a hidden field" do
      it "masks the value" do
        expect(field_cell_text("token", IronAdmin::Field.new(:value, type: :hidden))).to eq("\u2022" * 8)
      end
    end

    context "with a text field" do
      it "renders the value as plain text" do
        expect(field_cell_text("in_review", IronAdmin::Field.new(:value, type: :text))).to eq("in_review")
      end
    end
  end

  def field_cell_text(value, field)
    preview = described_class.new(total_rows: 1, headers: [], mapping: {}, rows: [], errors: [], fields: { value: field })
    preview.cell_text(IronAdmin::Import::Row.new(number: 1, attributes: { value: value }, errors: []), :value)
  end
end
