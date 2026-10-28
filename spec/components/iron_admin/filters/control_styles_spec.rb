require "rails_helper"

RSpec.describe IronAdmin::Filters::ControlStyles do
  let(:theme) { IronAdmin::Configuration::Theme.new }
  let(:midnight) do
    IronAdmin::Configuration::Theme.new(name: :midnight).tap do |t|
      t.label_transform = "uppercase tracking-wider"
      t.input_border = "border-zinc-700"
      t.card_bg = "bg-zinc-900"
      t.control_radius = "rounded-none"
      t.btn_secondary = "bg-zinc-800 text-zinc-100"
      t.popover_shadow = "shadow-2xl"
      t.btn_primary = "bg-lime-400 text-zinc-950"
    end
  end

  describe ".label" do
    subject(:classes) { described_class.label(theme).split }

    it "sets a small medium-weight label" do
      expect(classes).to include("block", "text-xs", "font-medium")
    end

    it "uses the theme's label color" do
      expect(classes).to include("text-zinc-700")
    end

    it "sets no case of its own, so the Neutral labels read as written" do
      expect(classes).not_to include("uppercase")
    end

    context "with a theme that transforms labels" do
      subject(:classes) { described_class.label(midnight).split }

      it "uses the theme's label transform" do
        expect(classes).to include("uppercase", "tracking-wider")
      end
    end
  end

  describe ".input" do
    subject(:classes) { described_class.input(theme).split }

    it "is 36px high" do
      expect(classes).to include("h-9")
    end

    it "uses the theme's border width, input border and control radius" do
      expect(classes).to include("border", "border-zinc-500/80", "hover:border-zinc-500", "rounded-md")
    end

    it "uses the theme's surface, text, placeholder and focus classes" do
      expect(classes).to include("bg-white", "text-zinc-900", "placeholder:text-zinc-500", "focus:ring-3")
    end

    it "takes its shadow from the theme's control shadow" do
      expect(classes.grep(/\Ashadow/)).to eq(["shadow-xs"])
    end

    it "hides the focus outline only where the ring shows, keeping it in forced-colors mode" do
      expect(classes).to include("outline-hidden")
    end

    it "matches the inputs of the forms" do
      expect(classes).to eq(IronAdmin::Form::ControlClasses.input(theme).split)
    end

    context "with another theme" do
      subject(:classes) { described_class.input(midnight).split }

      it "uses that theme's classes" do
        expect(classes).to include("border-zinc-700", "bg-zinc-900", "rounded-none")
      end
    end
  end

  describe ".select" do
    subject(:classes) { described_class.select(theme).split }

    it "draws the chevron with the engine's cp-select-chevron class" do
      expect(classes).to include("appearance-none", "cp-select-chevron")
    end

    it "keeps room for the chevron" do
      expect(classes).to include("pl-3", "pr-9")
    end

    it "is 36px high with the theme's input classes" do
      expect(classes).to include("h-9", "border", "border-zinc-500/80", "rounded-md", "bg-white")
    end

    it "matches the selects of the forms" do
      expect(classes).to eq(IronAdmin::Form::ControlClasses.select(theme).split)
    end
  end

  describe ".search_input" do
    subject(:classes) { described_class.search_input(theme).split }

    it "keeps room for the magnifying glass" do
      expect(classes).to include("pl-9", "pr-3")
    end

    it "is 36px high with the theme's input classes" do
      expect(classes).to include("h-9", "border", "border-zinc-500/80", "rounded-md", "bg-white", "placeholder:text-zinc-500")
    end

    it "matches the inputs of the forms" do
      expect(classes).to eq(IronAdmin::Form::ControlClasses.input(theme, padding: "pl-9 pr-3").split)
    end
  end

  describe ".trigger" do
    subject(:classes) { described_class.trigger(theme).split }

    it "is a 36px button" do
      expect(classes).to include("inline-flex", "items-center", "h-9", "text-sm", "font-medium", "cursor-pointer")
    end

    it "uses the theme's secondary button, control radius and focus ring" do
      expect(classes).to include("bg-white", "border-zinc-200", "rounded-md", "focus-visible:outline-indigo-500")
    end

    it "hides the disclosure marker of the summary" do
      expect(classes).to include("[&::-webkit-details-marker]:hidden")
    end

    it "looks like the secondary buttons of the forms" do
      expect(classes).to include(*IronAdmin::Form::ControlClasses.button(theme, :secondary).split)
    end

    context "with another theme" do
      subject(:classes) { described_class.trigger(midnight).split }

      it "uses that theme's secondary button" do
        expect(classes).to include("bg-zinc-800", "text-zinc-100", "rounded-none")
      end
    end
  end

  describe ".panel" do
    subject(:classes) { described_class.panel(theme).split }

    it "floats below the trigger" do
      expect(classes).to include("absolute", "right-0", "top-full", "z-20", "w-72")
    end

    it "uses the theme's card surface, border and radius" do
      expect(classes).to include("bg-white", "border", "border-zinc-200", "rounded-lg")
    end

    it "uses the theme's popover shadow" do
      expect(classes).to include("shadow-lg")
    end

    context "with another theme" do
      subject(:classes) { described_class.panel(midnight).split }

      it "uses that theme's popover shadow" do
        expect(classes).to include("shadow-2xl")
      end

      it "follows that theme's card_bg while popover_bg is empty" do
        expect(classes).to include("bg-zinc-900")
      end
    end

    context "with a theme that sets popover_bg" do
      subject(:classes) { described_class.panel(midnight.tap { |t| t.popover_bg = "bg-zinc-800" }).split }

      it "draws the panel on popover_bg" do
        expect(classes).to include("bg-zinc-800")
      end

      it "does not draw it on card_bg" do
        expect(classes).not_to include("bg-zinc-900")
      end
    end
  end

  describe ".count" do
    subject(:classes) { described_class.count(theme).split }

    it "uses the theme's badge counter colors and badge shape" do
      expect(classes).to include("bg-zinc-100", "text-zinc-700", "rounded-md", "font-medium")
    end

    it "aligns the figures" do
      expect(classes).to include("tabular-nums")
    end
  end

  describe ".footer" do
    subject(:classes) { described_class.footer(theme).split }

    it "separates the actions with a top border in the theme's card border color" do
      expect(classes).to include("border-t", "border-zinc-200")
    end
  end

  describe ".apply_button" do
    subject(:classes) { described_class.apply_button(theme).split }

    it "is a 36px button with the theme's control radius" do
      expect(classes).to include("h-9", "text-sm", "font-medium", "rounded-md")
    end

    it "uses the theme's primary button" do
      expect(classes).to include("bg-zinc-900", "text-white")
    end

    it "matches the primary buttons of the forms" do
      expect(classes).to eq(IronAdmin::Form::ControlClasses.button(theme, :primary).split)
    end

    context "with another theme" do
      subject(:classes) { described_class.apply_button(midnight).split }

      it "uses that theme's primary button" do
        expect(classes).to include("bg-lime-400", "text-zinc-950")
      end
    end
  end
end
