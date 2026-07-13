# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::MenuItem do
  subject(:menu_item) { described_class.new(label: "Reports", path: "/admin/reports") }

  describe "#initialize" do
    context "with only required attributes" do
      it "defaults the group to 'Plugins'" do
        expect(menu_item.group).to eq("Plugins")
      end

      it "defaults the priority to 999" do
        expect(menu_item.priority).to eq(999)
      end

      it "defaults the icon to nil" do
        expect(menu_item.icon).to be_nil
      end
    end

    context "with a blank label" do
      it "raises an ArgumentError" do
        expect { described_class.new(label: "  ", path: "/x") }
          .to raise_error(ArgumentError, /label can't be blank/)
      end
    end

    context "with a blank path" do
      it "raises an ArgumentError" do
        expect { described_class.new(label: "Reports", path: "") }
          .to raise_error(ArgumentError, /path can't be blank/)
      end
    end

    context "with a non-integer priority" do
      it "coerces a numeric string to an Integer" do
        item = described_class.new(label: "Reports", path: "/x", priority: "50")
        expect(item.priority).to eq(50)
      end

      it "falls back to 999 for a non-numeric value" do
        item = described_class.new(label: "Reports", path: "/x", priority: "high")
        expect(item.priority).to eq(999)
      end
    end

    context "with a blank group" do
      it "normalizes it to 'Plugins'" do
        item = described_class.new(label: "Reports", path: "/x", group: "  ")
        expect(item.group).to eq("Plugins")
      end
    end
  end

  describe "#key" do
    it "combines group, label, and path" do
      item = described_class.new(label: "Reports", path: "/admin/reports", group: "Analytics")
      expect(item.key).to eq("Analytics::Reports::/admin/reports")
    end
  end
end
