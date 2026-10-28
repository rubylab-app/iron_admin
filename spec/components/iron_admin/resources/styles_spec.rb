require "rails_helper"

RSpec.describe IronAdmin::Resources::Styles do
  let(:theme) { IronAdmin::Configuration::Theme.new }
  let(:midnight) do
    IronAdmin::Configuration::Theme.new(name: :midnight).tap do |t|
      t.page_title = "text-2xl font-black text-white"
      t.heading_font = "font-[family-name:Space_Grotesk]"
      t.card_bg = "bg-zinc-900"
      t.border_width = "border-2"
      t.table_frame = "ring-1 ring-zinc-700"
      t.table_cell_padding = "px-3 py-1.5"
      t.label_transform = "uppercase tracking-wider"
      t.table_sticky_shadow = "shadow-none"
    end
  end

  describe ".page_title" do
    it "uses the theme's page title and heading font" do
      expect(described_class.page_title(midnight).split).to eq(%w[text-2xl font-black text-white font-[family-name:Space_Grotesk]])
    end

    it "uses the Neutral page title" do
      expect(described_class.page_title(theme).split).to eq(%w[text-xl font-semibold tracking-tight text-zinc-900])
    end
  end

  describe ".panel" do
    subject(:classes) { described_class.panel(theme).split }

    it "uses the theme's card surface, border width, border color, radius and shadow" do
      expect(classes).to eq(%w[bg-white border border-zinc-200 rounded-lg shadow-xs])
    end

    context "with another theme" do
      subject(:classes) { described_class.panel(midnight).split }

      it "uses that theme's card surface and border width" do
        expect(classes).to include("bg-zinc-900", "border-2")
      end
    end
  end

  describe ".panel_header" do
    it "separates the header with a bottom border in the theme's card border color" do
      expect(described_class.panel_header(theme).split).to include("border-b", "border-zinc-200")
    end
  end

  describe ".panel_title" do
    it "uses the theme's card title and heading font" do
      expect(described_class.panel_title(midnight).split).to include("font-[family-name:Space_Grotesk]")
    end

    it "uses the Neutral card title" do
      expect(described_class.panel_title(theme).split).to eq(%w[text-sm font-semibold text-zinc-900])
    end
  end

  describe ".table_frame" do
    subject(:classes) { described_class.table_frame(midnight).split }

    it "scrolls the table sideways inside a panel" do
      expect(classes).to include("overflow-x-auto", "bg-zinc-900", "border-2")
    end

    it "adds the theme's table frame" do
      expect(classes).to include("ring-1", "ring-zinc-700")
    end
  end

  describe ".table" do
    it "divides the head from the body in the theme's table border color" do
      expect(described_class.table(theme).split).to include("min-w-full", "divide-y", "divide-zinc-200")
    end

    context "with a theme that sets table_head_border" do
      before { theme.table_head_border = "divide-stone-900" }

      it "divides the head from the body in that color" do
        expect(described_class.table(theme).split).to include("divide-stone-900")
      end

      it "does not use table_border for that line" do
        expect(described_class.table(theme).split).not_to include("divide-zinc-200")
      end
    end
  end

  describe ".divided" do
    it "divides rows in the theme's table border color" do
      expect(described_class.divided(theme).split).to eq(%w[divide-y divide-zinc-200])
    end
  end

  describe ".list_row" do
    subject(:classes) { described_class.list_row(theme).split }

    it "rounds the first and last rows like their panel" do
      expect(classes).to include("first:rounded-t-[inherit]", "last:rounded-b-[inherit]")
    end

    it "uses the theme's body text, item hover and focus ring" do
      expect(classes).to include("text-zinc-900", "hover:bg-zinc-100", "focus-visible:outline-indigo-500")
    end
  end

  describe ".header_cell" do
    subject(:classes) { described_class.header_cell(theme).split }

    it "uses the theme's header text and cell padding" do
      expect(classes).to include("text-xs", "font-medium", "text-zinc-500", "px-4", "py-2.5")
    end

    it "writes the Neutral headers as they are, without uppercase" do
      expect(classes).not_to include("uppercase")
    end

    context "with a theme that transforms labels" do
      subject(:classes) { described_class.header_cell(midnight).split }

      it "uses that theme's label transform and padding" do
        expect(classes).to include("uppercase", "tracking-wider", "px-3", "py-1.5")
      end
    end
  end

  describe ".cell" do
    it "uses the theme's cell padding and body text" do
      expect(described_class.cell(theme).split).to include("text-sm", "px-4", "py-2.5", "text-zinc-900")
    end

    {
      number: true,
      currency: true,
      string: false,
      badge: false,
    }.each do |type, tabular|
      context "with a #{type} field" do
        let(:field) { IronAdmin::Field.new(:value, type: type) }

        it(tabular ? "lines up the digits" : "keeps proportional digits") do
          expect(described_class.cell(theme, field).split.include?("tabular-nums")).to be(tabular)
        end
      end
    end
  end

  describe ".muted_cell" do
    it "uses the theme's muted text" do
      expect(described_class.muted_cell(theme).split).to include("px-4", "py-2.5", "text-zinc-500")
    end
  end

  describe ".sticky_header_cell" do
    subject(:classes) { described_class.sticky_header_cell(theme).split }

    it "sticks to the right edge over the header background" do
      expect(classes).to include("sticky", "right-0", "z-10", "bg-zinc-50")
    end

    it "casts the theme's sticky column shadow" do
      expect(classes).to include("shadow-[-4px_0_6px_-4px_rgba(0,0,0,0.08)]")
    end
  end

  describe ".sticky_cell" do
    it "sticks to the right edge over the card background" do
      expect(described_class.sticky_cell(theme).split).to include("sticky", "right-0", "z-10", "bg-white")
    end

    it "casts the sticky column shadow of the theme" do
      expect(described_class.sticky_cell(midnight).split).to include("shadow-none")
    end

    context "with a theme that sets table_sticky_row_hover" do
      before { theme.table_sticky_row_hover = "group-hover/row:bg-zinc-50" }

      it "follows the hover of its row" do
        expect(described_class.sticky_cell(theme).split).to include("group-hover/row:bg-zinc-50")
      end
    end
  end

  {
    secondary_button: %w[bg-white text-zinc-900 border-zinc-200],
    ghost_button: %w[bg-transparent text-zinc-700 hover:bg-zinc-100],
  }.each do |recipe, colors|
    describe ".#{recipe}" do
      subject(:classes) { described_class.public_send(recipe, theme).split }

      it "is a 36px button" do
        expect(classes).to include("inline-flex", "items-center", "h-9", "px-3.5", "text-sm", "font-medium")
      end

      it "uses the theme's button colors, control radius and focus ring" do
        expect(classes).to include(*colors, "rounded-md", "focus-visible:outline-indigo-500")
      end
    end
  end

  describe ".secondary_button" do
    it "matches the secondary buttons of the forms" do
      expect(described_class.secondary_button(theme)).to eq(IronAdmin::Form::ControlClasses.button(theme, :secondary))
    end

    it "casts the theme's control shadow" do
      expect(described_class.secondary_button(theme).split).to include("shadow-xs")
    end
  end

  describe ".ghost_button" do
    it "matches the ghost buttons of the forms" do
      expect(described_class.ghost_button(theme)).to eq(IronAdmin::Form::ControlClasses.button(theme, :ghost))
    end

    it "stays flat, like every ghost button" do
      expect(described_class.ghost_button(theme).split).not_to include("shadow-xs")
    end
  end
end
