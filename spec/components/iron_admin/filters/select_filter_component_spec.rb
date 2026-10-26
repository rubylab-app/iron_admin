require "rails_helper"
require_relative "../../../../app/components/iron_admin/filters/select_filter_component"

RSpec.describe IronAdmin::Filters::SelectFilterComponent, type: :component do
  let(:options) { [%w[Active active], %w[Inactive inactive]] }

  describe "#initialize" do
    it "stores name" do
      component = described_class.new(name: :status, options: options)
      expect(component.name).to eq(:status)
    end

    it "stores options" do
      component = described_class.new(name: :status, options: options)
      expect(component.options).to eq(options)
    end

    it "generates label from name when not provided" do
      component = described_class.new(name: :user_status, options: options)
      expect(component.label).to eq("User status")
    end

    it "accepts custom label" do
      component = described_class.new(name: :status, label: "Account Status", options: options)
      expect(component.label).to eq("Account Status")
    end

    it "defaults selected to nil" do
      component = described_class.new(name: :status, options: options)
      expect(component.selected).to be_nil
    end

    it "accepts selected value" do
      component = described_class.new(name: :status, options: options, selected: "active")
      expect(component.selected).to eq("active")
    end
  end

  describe "#field_name" do
    it "generates correct field name" do
      component = described_class.new(name: :status, options: options)
      expect(component.field_name).to eq("filters[status]")
    end
  end

  describe "#label_classes" do
    it "includes text-xs" do
      component = described_class.new(name: :status, options: options)
      expect(component.label_classes).to include("text-xs")
    end

    it "includes font-semibold" do
      component = described_class.new(name: :status, options: options)
      expect(component.label_classes).to include("font-semibold")
    end

    it "includes uppercase" do
      component = described_class.new(name: :status, options: options)
      expect(component.label_classes).to include("uppercase")
    end
  end

  describe "#select_classes" do
    it "includes full width" do
      component = described_class.new(name: :status, options: options)
      expect(component.select_classes).to include("w-full")
    end

    it "includes appearance-none" do
      component = described_class.new(name: :status, options: options)
      expect(component.select_classes).to include("appearance-none")
    end

    it "includes border" do
      component = described_class.new(name: :status, options: options)
      expect(component.select_classes).to include("border")
    end

    it "includes text-sm" do
      component = described_class.new(name: :status, options: options)
      expect(component.select_classes).to include("text-sm")
    end
  end

  describe "#chevron_style" do
    it "includes background-image for chevron" do
      component = described_class.new(name: :status, options: options)
      expect(component.chevron_style).to include("background-image")
    end

    it "includes background-position" do
      component = described_class.new(name: :status, options: options)
      expect(component.chevron_style).to include("background-position")
    end

    it "includes padding-right for chevron space" do
      component = described_class.new(name: :status, options: options)
      expect(component.chevron_style).to include("padding-right")
    end
  end

  describe "accessible names" do
    let(:html) { render_inline(described_class.new(name: :status, options: options)).to_html }

    it "points the label at the select" do
      expect(form_accessibility_problems(html)).to be_empty
    end

    it "gives the select a stable id" do
      expect(Nokogiri::HTML5(html).at_css("select")["id"]).to eq("filters_status")
    end
  end
end
