require "rails_helper"
require_relative "../../../../app/components/iron_admin/ui/button_component"

RSpec.describe IronAdmin::Ui::ButtonComponent, type: :component do
  describe "#initialize" do
    it "defaults variant to primary" do
      component = described_class.new(text: "Click")
      expect(component.variant).to eq(:primary)
    end

    it "defaults size to md" do
      component = described_class.new(text: "Click")
      expect(component.size).to eq(:md)
    end

    it "defaults type to button" do
      component = described_class.new(text: "Click")
      expect(component.type).to eq(:button)
    end

    it "accepts all options" do
      component = described_class.new(
        text: "Submit",
        variant: :danger,
        size: :lg,
        icon: "trash",
        href: "/delete",
        method: :delete,
        confirm: "Are you sure?",
        disabled: true
      )
      expect(component.text).to eq("Submit")
      expect(component.variant).to eq(:danger)
      expect(component.size).to eq(:lg)
      expect(component.icon).to eq("trash")
      expect(component.href).to eq("/delete")
      expect(component.method).to eq(:delete)
      expect(component.confirm).to eq("Are you sure?")
      expect(component.disabled).to be true
    end
  end

  describe "#variant_classes" do
    it "returns primary classes" do
      component = described_class.new(text: "Test", variant: :primary)
      expect(component.variant_classes).to include("bg-zinc-900")
    end

    it "returns secondary classes" do
      component = described_class.new(text: "Test", variant: :secondary)
      expect(component.variant_classes).to include("bg-white")
    end

    it "returns danger classes" do
      component = described_class.new(text: "Test", variant: :danger)
      expect(component.variant_classes).to include("bg-red-600")
    end

    it "returns ghost classes" do
      component = described_class.new(text: "Test", variant: :ghost)
      expect(component.variant_classes).to include("bg-transparent")
    end
  end

  describe "#size_classes" do
    it "returns sm classes" do
      component = described_class.new(text: "Test", size: :sm)
      expect(component.size_classes).to include("py-1.5")
    end

    it "returns md classes" do
      component = described_class.new(text: "Test", size: :md)
      expect(component.size_classes).to include("py-2")
    end

    it "returns lg classes" do
      component = described_class.new(text: "Test", size: :lg)
      expect(component.size_classes).to include("py-2.5")
    end
  end

  describe "#data_attributes" do
    it "includes turbo_method when method is set" do
      component = described_class.new(text: "Delete", method: :delete)
      expect(component.data_attributes[:turbo_method]).to eq(:delete)
    end

    it "includes turbo_confirm when confirm is set" do
      component = described_class.new(text: "Delete", confirm: "Sure?")
      expect(component.data_attributes[:turbo_confirm]).to eq("Sure?")
    end

    it "returns empty hash when no data attributes" do
      component = described_class.new(text: "Click")
      expect(component.data_attributes).to eq({})
    end
  end

  describe "#call" do
    it "renders a button element without href" do
      result = render_inline(described_class.new(text: "Click"))
      expect(result.css("button")).to be_present
      expect(result.css("button").text.strip).to eq("Click")
    end

    it "renders a link element with href" do
      result = render_inline(described_class.new(text: "Go", href: "/path"))
      expect(result.css("a[href='/path']")).to be_present
    end

    it "includes disabled attribute when disabled" do
      result = render_inline(described_class.new(text: "Disabled", disabled: true))
      expect(result.css("button[disabled]")).to be_present
    end
  end
end
