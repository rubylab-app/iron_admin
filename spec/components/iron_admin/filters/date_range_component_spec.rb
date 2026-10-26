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
    it "includes text-xs" do
      component = described_class.new(name: :created_at)
      expect(component.label_classes).to include("text-xs")
    end

    it "includes font-semibold" do
      component = described_class.new(name: :created_at)
      expect(component.label_classes).to include("font-semibold")
    end

    it "includes uppercase" do
      component = described_class.new(name: :created_at)
      expect(component.label_classes).to include("uppercase")
    end
  end

  describe "#input_classes" do
    it "includes full width" do
      component = described_class.new(name: :created_at)
      expect(component.input_classes).to include("w-full")
    end

    it "includes border" do
      component = described_class.new(name: :created_at)
      expect(component.input_classes).to include("border")
    end

    it "includes text-sm" do
      component = described_class.new(name: :created_at)
      expect(component.input_classes).to include("text-sm")
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
  end
end
