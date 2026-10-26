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
    end
  end
end
