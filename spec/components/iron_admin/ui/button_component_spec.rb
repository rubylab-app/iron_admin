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
      expect(component.size_classes.split).to include("h-8", "px-3")
    end

    it "returns md classes, 36px high" do
      component = described_class.new(text: "Test", size: :md)
      expect(component.size_classes.split).to include("h-9", "px-3.5", "text-sm")
    end

    it "returns lg classes" do
      component = described_class.new(text: "Test", size: :lg)
      expect(component.size_classes.split).to include("h-10", "px-4")
    end
  end

  describe "#button_classes" do
    subject(:classes) { described_class.new(text: "Test", variant: variant).button_classes.split }

    let(:variant) { :secondary }

    context "with the default theme" do
      it "rounds the button with the theme's control_radius" do
        expect(classes).to include("rounded-md")
      end

      it "outlines a focused button with the theme's focus_ring" do
        expect(classes).to include("focus-visible:outline-2", "focus-visible:outline-indigo-500")
      end

      it "shows the pointer cursor, which Tailwind v4's preflight no longer gives buttons" do
        expect(classes).to include("cursor-pointer")
      end
    end

    context "with the theme's control_shadow" do
      before { IronAdmin.configuration.theme { |t| t.control_shadow = "shadow-sm" } }

      %i[primary secondary danger].each do |raised|
        context "with the #{raised} variant" do
          let(:variant) { raised }

          it "casts the control shadow, like the form buttons" do
            expect(classes).to include("shadow-sm")
          end
        end
      end

      context "with the ghost variant" do
        let(:variant) { :ghost }

        it "stays flat" do
          expect(classes).not_to include("shadow-sm")
        end
      end
    end

    context "with the primary variant, whose btn_primary carries its own focus outline" do
      let(:variant) { :primary }

      before do
        IronAdmin.configuration.theme do |t|
          t.btn_primary = "bg-black text-white focus-visible:outline-black"
          t.focus_ring = "focus-visible:outline-indigo-500"
        end
      end

      it "keeps btn_primary's focus outline" do
        expect(classes).to include("focus-visible:outline-black")
      end

      it "leaves out the focus_ring, which would set the outline color twice" do
        expect(classes).not_to include("focus-visible:outline-indigo-500")
      end
    end

    context "with a registered theme active" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:brutal) do |t|
          t.btn_secondary = "bg-yellow-300 text-black border-2 border-black"
          t.control_radius = "rounded-none"
        end
      end

      it "uses that theme's variant classes" do
        expect(classes).to include("bg-yellow-300", "border-black")
      end

      it "rounds the button with that theme's control_radius" do
        expect(classes).to include("rounded-none")
      end

      it "drops the default theme's radius" do
        expect(classes).not_to include("rounded-md")
      end
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
