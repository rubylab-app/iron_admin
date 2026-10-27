# frozen_string_literal: true

require "rails_helper"

# Properties the index, show, search and audit pages added to the catalog.
RSpec.describe IronAdmin::Configuration::Theme do
  subject(:theme) { described_class.new }

  {
    popover_shadow: "shadow-lg",
    table_sticky_shadow: "shadow-[-4px_0_6px_-4px_rgba(0,0,0,0.08)]",
  }.each do |property, neutral|
    describe "##{property}" do
      it "defaults to the Neutral value" do
        expect(theme.public_send(property)).to eq(neutral)
      end

      context "when set" do
        before { theme.public_send(:"#{property}=", "shadow-none") }

        it "returns the value set" do
          expect(theme.public_send(property)).to eq("shadow-none")
        end
      end

      context "when set to an empty String" do
        before { theme.public_send(:"#{property}=", "") }

        it "returns the empty String, so the theme has no shadow there" do
          expect(theme.public_send(property)).to eq("")
        end
      end

      context "with a registered theme" do
        subject(:registered) { IronAdmin.configuration.register_theme(:midnight) { |t| t.public_send(:"#{property}=", "x") } }

        it "keeps the value the block set" do
          expect(registered.public_send(property)).to eq("x")
        end
      end

      context "with a copy" do
        subject(:copy) { theme.dup }

        before { theme.public_send(:"#{property}=", "shadow-md") }

        it "keeps the value of the original" do
          expect(copy.public_send(property)).to eq("shadow-md")
        end
      end
    end
  end
end
