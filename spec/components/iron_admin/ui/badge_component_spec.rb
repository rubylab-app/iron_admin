require "rails_helper"
require_relative "../../../../app/components/iron_admin/ui/badge_component"

RSpec.describe IronAdmin::Ui::BadgeComponent, type: :component do
  subject(:component) { described_class.new(text: "Active", color: color) }

  let(:color) { :green }
  let(:midnight) do
    IronAdmin.configuration.register_theme(:midnight) do |t|
      t.badge_palette[:green] = "bg-emerald-950 text-emerald-300"
      t.badge_dot_palette[:green] = "bg-emerald-400"
      t.badge_shape = "rounded-none font-bold"
    end
  end

  describe "COLORS" do
    it "keeps every color name" do
      expect(described_class::COLORS.keys).to eq(%i[green red yellow blue indigo purple pink orange teal gray])
    end

    it "holds the classes of the Neutral badge palette" do
      expect(described_class::COLORS).to eq(IronAdmin::Configuration::Theme.new.badge_palette)
    end

    it "is frozen" do
      expect(described_class::COLORS).to be_frozen
    end
  end

  describe "#initialize" do
    it "stores text" do
      expect(component.text).to eq("Active")
    end

    it "defaults color to gray" do
      expect(described_class.new(text: "Test").color).to eq(:gray)
    end

    it "defaults size to md" do
      expect(described_class.new(text: "Test").size).to eq(:md)
    end

    it "accepts custom color" do
      expect(component.color).to eq(:green)
    end

    it "accepts custom size" do
      expect(described_class.new(text: "Test", size: :lg).size).to eq(:lg)
    end
  end

  describe "#color_classes" do
    subject(:color_classes) { component.color_classes }

    it "returns the color's classes from the theme's badge palette" do
      expect(color_classes).to eq("bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-600/20")
    end

    context "with a String color" do
      let(:color) { "green" }

      it "returns the same classes as the Symbol" do
        expect(color_classes).to eq(IronAdmin.current_theme.badge_palette[:green])
      end
    end

    context "with a color the palette does not have" do
      let(:color) { :unknown }

      it "falls back to the gray badge" do
        expect(color_classes).to eq(IronAdmin.current_theme.badge_palette[:gray])
      end
    end

    context "with config.badge_colors classes for the color" do
      before { IronAdmin.configuration.badge_colors[:green] = "bg-lime-100 text-lime-900" }

      it "returns those classes instead of the palette's" do
        expect(color_classes).to eq("bg-lime-100 text-lime-900")
      end
    end

    context "with a color only config.badge_colors defines" do
      let(:color) { :cyan }

      before { IronAdmin.configuration.badge_colors[:cyan] = "bg-cyan-100 text-cyan-800" }

      it "returns its classes" do
        expect(color_classes).to eq("bg-cyan-100 text-cyan-800")
      end
    end

    context "with a registered theme active" do
      before { IronAdmin::Current.theme = midnight }

      it "returns that theme's classes" do
        expect(color_classes).to eq("bg-emerald-950 text-emerald-300")
      end
    end

    context "with a theme whose palette has no gray" do
      let(:color) { :unknown }

      before { IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:bare) { |t| t.badge_palette = {} } }

      it "returns no classes" do
        expect(color_classes).to eq("")
      end
    end
  end

  describe "#dot_classes" do
    subject(:dot_classes) { component.dot_classes }

    it "returns the color's dot from the theme's badge dot palette" do
      expect(dot_classes).to eq("bg-emerald-500")
    end

    context "with a color the palette does not have" do
      let(:color) { :unknown }

      it "returns the gray dot" do
        expect(dot_classes).to eq(IronAdmin.current_theme.badge_dot_palette[:gray])
      end
    end

    context "with config.badge_colors classes for the color" do
      before { IronAdmin.configuration.badge_colors[:green] = "bg-lime-100 text-lime-900" }

      it "returns nil, so the configured classes alone style the badge" do
        expect(dot_classes).to be_nil
      end
    end

    context "with a theme without dots" do
      before { IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:flat) { |t| t.badge_dot_palette = {} } }

      it "returns nil" do
        expect(dot_classes).to be_nil
      end
    end
  end

  describe "#size_classes" do
    {
      sm: "px-1.5 py-0.5 text-xs",
      md: "px-2 py-0.5 text-xs",
      lg: "px-2.5 py-1 text-sm",
    }.each do |size, classes|
      context "with size #{size}" do
        it "returns #{classes}" do
          expect(described_class.new(text: "Test", size: size).size_classes).to eq(classes)
        end
      end
    end

    context "with an unknown size" do
      it "returns the md classes" do
        expect(described_class.new(text: "Test", size: :xl).size_classes).to eq(described_class::SIZES[:md])
      end
    end
  end

  describe "#call" do
    subject(:badge) { render_inline(component).at_css("span") }

    let(:badge_classes) { badge[:class].split }
    let(:dot) { badge.at_css("span") }

    it "renders the text" do
      expect(badge.text).to eq("Active")
    end

    it "lays out the dot and the text in a row" do
      expect(badge_classes).to include("inline-flex", "items-center", "gap-1.5")
    end

    it "uses the theme's badge shape" do
      expect(badge_classes).to include("rounded-md", "font-medium")
    end

    it "uses the palette classes" do
      expect(badge_classes).to include("bg-emerald-50", "text-emerald-700")
    end

    it "renders a 6px round dot in the dot palette color" do
      expect(dot[:class].split).to include("h-1.5", "w-1.5", "rounded-full", "bg-emerald-500")
    end

    it "hides the dot from screen readers" do
      expect(dot["aria-hidden"]).to eq("true")
    end

    context "with config.badge_colors classes for the color" do
      before { IronAdmin.configuration.badge_colors[:green] = "bg-lime-100 text-lime-900" }

      it "renders no dot" do
        expect(dot).to be_nil
      end
    end

    context "with a registered theme active" do
      before { IronAdmin::Current.theme = midnight }

      it "uses that theme's shape and palette" do
        expect(badge_classes).to include("rounded-none", "font-bold", "bg-emerald-950", "text-emerald-300")
      end

      it "uses that theme's dot" do
        expect(dot[:class].split).to include("bg-emerald-400")
      end
    end
  end
end
