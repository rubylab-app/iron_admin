require "rails_helper"
require_relative "../../../../app/components/iron_admin/ui/modal_component"

RSpec.describe IronAdmin::Ui::ModalComponent, type: :component do
  describe "#initialize" do
    it "defaults size to md" do
      component = described_class.new
      expect(component.size).to eq(:md)
    end

    it "defaults dismissible to true" do
      component = described_class.new
      expect(component.dismissible).to be true
    end

    it "accepts custom size" do
      component = described_class.new(size: :lg)
      expect(component.size).to eq(:lg)
    end

    it "accepts dismissible false" do
      component = described_class.new(dismissible: false)
      expect(component.dismissible).to be false
    end

    it "converts string size to symbol" do
      component = described_class.new(size: "xl")
      expect(component.size).to eq(:xl)
    end
  end

  describe "#size_classes" do
    it "returns max-w-md for sm size" do
      component = described_class.new(size: :sm)
      expect(component.size_classes).to eq("max-w-md")
    end

    it "returns max-w-lg for md size" do
      component = described_class.new(size: :md)
      expect(component.size_classes).to eq("max-w-lg")
    end

    it "returns max-w-2xl for lg size" do
      component = described_class.new(size: :lg)
      expect(component.size_classes).to eq("max-w-2xl")
    end

    it "returns max-w-4xl for xl size" do
      component = described_class.new(size: :xl)
      expect(component.size_classes).to eq("max-w-4xl")
    end

    it "returns full width for full size" do
      component = described_class.new(size: :full)
      expect(component.size_classes).to include("max-w-full")
    end

    it "falls back to md for unknown size" do
      component = described_class.new(size: :unknown)
      expect(component.size_classes).to eq("max-w-lg")
    end
  end

  describe "#modal_classes" do
    it "includes relative positioning" do
      component = described_class.new
      expect(component.modal_classes).to include("relative")
    end

    it "includes size class" do
      component = described_class.new(size: :lg)
      expect(component.modal_classes).to include("max-w-2xl")
    end

    it "includes full width" do
      component = described_class.new
      expect(component.modal_classes).to include("w-full")
    end

    context "with the default theme" do
      subject(:classes) { described_class.new.modal_classes.split }

      it "draws the panel as a theme surface" do
        expect(classes).to include("bg-white", "border", "border-zinc-200", "rounded-lg")
      end

      it "lifts the panel with the theme's popover_shadow" do
        expect(classes).to include("shadow-lg")
      end

      it "builds no shadow class out of card_shadow" do
        expect(classes.grep(/\Ashadow-xs-/)).to be_empty
      end
    end

    context "with a registered theme active" do
      subject(:classes) { described_class.new.modal_classes.split }

      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:brutal) do |t|
          t.popover_shadow = "shadow-[6px_6px_0_0_var(--color-zinc-950)]"
          t.border_width = "border-2"
        end
      end

      it "uses that theme's popover_shadow and border_width" do
        expect(classes).to include("shadow-[6px_6px_0_0_var(--color-zinc-950)]", "border-2")
      end
    end
  end

  describe "header" do
    subject(:dialog) { render_inline(component).at_css("[role=dialog]") }

    let(:component) { described_class.new.with_title_content("Delete user").with_content("Body") }

    it "titles the dialog with the theme's card_title" do
      expect(dialog.at_css("h3")[:class].split).to include("text-sm", "font-semibold", "text-zinc-900")
    end

    it "styles the close button as a ghost icon button" do
      expect(dialog.at_css("button")[:class].split).to include("hover:bg-zinc-100", "rounded-md", "focus-visible:outline-indigo-500")
    end
  end

  describe "backdrop" do
    subject(:backdrop) { render_inline(described_class.new.with_content("Body")).at_css("div.fixed.inset-0.transition-opacity") }

    it "uses the theme's translucent overlay background" do
      expect(backdrop[:class].split).to include("bg-zinc-900/40")
    end

    it "does not use the bg-opacity utility that Tailwind v4 removed" do
      expect(backdrop[:class]).not_to include("bg-opacity")
    end
  end

  describe "dismissing" do
    subject(:dialog) { render_inline(component.with_content("Body")).at_css("[role=dialog]") }

    let(:close_button) { dialog.at_css("button") }
    let(:backdrop) { dialog.at_css("div.fixed.inset-0.transition-opacity") }

    context "when dismissible" do
      let(:component) { described_class.new }

      it "attaches the cp-modal Stimulus controller" do
        expect(dialog["data-controller"]).to eq("cp-modal")
      end

      it "closes on Escape" do
        expect(dialog["data-action"]).to eq("keydown.esc@window->cp-modal#close")
      end

      it "closes when the backdrop is clicked" do
        expect(backdrop["data-action"]).to eq("click->cp-modal#close")
      end

      it "wires the close button to the controller" do
        expect(close_button["data-action"]).to eq("cp-modal#close")
      end

      it "labels the close button for screen readers" do
        expect(close_button["aria-label"]).to eq("Close")
      end
    end

    context "when not dismissible" do
      let(:component) { described_class.new(dismissible: false) }

      it "attaches no Stimulus controller" do
        expect(dialog["data-controller"]).to be_nil
      end

      it "renders no close button" do
        expect(close_button).to be_nil
      end
    end
  end

  describe "close controller" do
    subject(:entry_point) { IronAdmin::Engine.root.join("app/javascript/iron_admin/index.js").read }

    it "is registered under the identifier the template uses" do
      expect(entry_point).to include(%(application.register("cp-modal", CpModalController)))
    end
  end

  describe "slots" do
    it "has title slot" do
      expect(described_class.registered_slots).to have_key(:title)
    end

    it "has footer slot" do
      expect(described_class.registered_slots).to have_key(:footer)
    end
  end
end
