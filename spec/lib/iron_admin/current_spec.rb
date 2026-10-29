# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Current do
  let(:theme) { IronAdmin::Configuration::Theme.new(name: :midnight) }

  describe ".theme" do
    it "is nil until a request sets it" do
      expect(described_class.theme).to be_nil
    end

    it "returns the theme set for the request" do
      described_class.theme = theme

      expect(described_class.theme).to equal(theme)
    end
  end

  describe ".reset" do
    it "clears the theme" do
      described_class.theme = theme
      described_class.reset

      expect(described_class.theme).to be_nil
    end
  end

  it "is a CurrentAttributes class, which Rails resets around every request" do
    expect(described_class.superclass).to eq(ActiveSupport::CurrentAttributes)
  end
end
