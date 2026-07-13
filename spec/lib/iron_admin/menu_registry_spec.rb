# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::MenuRegistry do
  def build_item(label: "Reports", path: "/admin/reports", **opts)
    IronAdmin::MenuItem.new(label: label, path: path, **opts)
  end

  describe ".register" do
    it "adds the item to the registry" do
      described_class.register(build_item)
      expect(described_class.all.map(&:label)).to eq(["Reports"])
    end

    context "when registering the same item twice" do
      it "does not create a duplicate" do
        described_class.register(build_item)
        described_class.register(build_item)
        expect(described_class.all.size).to eq(1)
      end
    end
  end

  describe ".grouped" do
    it "groups items by their group heading" do
      described_class.register(build_item(label: "A", path: "/a", group: "Analytics"))
      described_class.register(build_item(label: "B", path: "/b", group: "Ops"))

      expect(described_class.grouped.keys).to contain_exactly("Analytics", "Ops")
    end
  end

  describe ".sorted" do
    it "orders items by ascending priority" do
      described_class.register(build_item(label: "Second", path: "/2", priority: 20))
      described_class.register(build_item(label: "First", path: "/1", priority: 10))

      expect(described_class.sorted.map(&:label)).to eq(%w[First Second])
    end
  end

  describe ".reset!" do
    it "clears all items" do
      described_class.register(build_item)
      described_class.reset!
      expect(described_class.all).to be_empty
    end
  end
end
