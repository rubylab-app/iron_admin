require "rails_helper"
require_relative "../../../../app/components/iron_admin/filters/date_range_component"

RSpec.describe IronAdmin::Filters::DateRangeComponent, type: :component do
  describe "#initialize" do
    it "stores name" do
      component = described_class.new(name: :created_at)
      expect(component.name).to eq(:created_at)
    end

    it "generates label from name when not provided" do
      component = described_class.new(name: :created_at)
      expect(component.label).to eq("Created at")
    end

    it "accepts custom label" do
      component = described_class.new(name: :created_at, label: "Date Created")
      expect(component.label).to eq("Date Created")
    end

    it "defaults from_value to nil" do
      component = described_class.new(name: :created_at)
      expect(component.from_value).to be_nil
    end

    it "defaults to_value to nil" do
      component = described_class.new(name: :created_at)
      expect(component.to_value).to be_nil
    end

    it "accepts from_value and to_value" do
      component = described_class.new(
        name: :created_at,
        from_value: "2024-01-01",
        to_value: "2024-12-31"
      )
      expect(component.from_value).to eq("2024-01-01")
      expect(component.to_value).to eq("2024-12-31")
    end
  end

  describe "#from_field_name" do
    it "generates correct field name for from date" do
      component = described_class.new(name: :created_at)
      expect(component.from_field_name).to eq("filters[created_at_from]")
    end
  end

  describe "#to_field_name" do
    it "generates correct field name for to date" do
      component = described_class.new(name: :created_at)
      expect(component.to_field_name).to eq("filters[created_at_to]")
    end
  end

  describe "#label_classes" do
    subject(:component) { described_class.new(name: :created_at) }

    it "uses the filter label classes of the current theme" do
      expect(component.label_classes).to eq(IronAdmin::Filters::ControlStyles.label(IronAdmin.current_theme))
    end

    it "includes text-xs" do
      expect(component.label_classes).to include("text-xs")
    end
  end

  describe "#input_classes" do
    subject(:input_classes) { described_class.new(name: :created_at).input_classes.split }

    it "includes full width" do
      expect(input_classes).to include("w-full")
    end

    it "uses the theme's border width" do
      expect(input_classes).to include("border")
    end

    it "includes text-sm" do
      expect(input_classes).to include("text-sm")
    end

    it "is 36px high" do
      expect(input_classes).to include("h-9")
    end

    context "with a registered theme active" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:midnight) do |t|
          t.input_border = "border-zinc-700"
        end
      end

      it "uses that theme's input border" do
        expect(input_classes).to include("border-zinc-700")
      end
    end
  end

  describe "accessible names" do
    let(:document) { Nokogiri::HTML5(render_inline(described_class.new(name: :created_at)).to_html) }

    it "points the label at the from input and names both inputs" do
      expect(form_accessibility_problems(document)).to be_empty
    end

    it "names the from input after the filter" do
      expect(document.at_css("input[name='filters[created_at_from]']")["aria-label"]).to eq("Created at from")
    end

    it "names the to input after the filter" do
      expect(document.at_css("input[name='filters[created_at_to]']")["aria-label"]).to eq("Created at to")
    end

    # Two date inputs look the same, so each says which end of the range it holds; the
    # inputs' names already say it to screen readers.
    it "shows From and To beside the two inputs" do
      markers = %w[from to].map { |edge| document.at_css("input[name='filters[created_at_#{edge}]']").parent.at_css("[aria-hidden=true]").text.strip }
      expect(markers).to eq(%w[From To])
    end
  end
end
