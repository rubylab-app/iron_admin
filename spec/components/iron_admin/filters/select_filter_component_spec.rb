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
    subject(:component) { described_class.new(name: :status, options: options) }

    it "uses the filter label classes of the current theme" do
      expect(component.label_classes).to eq(IronAdmin::Filters::ControlStyles.label(IronAdmin.current_theme))
    end

    it "includes text-xs" do
      expect(component.label_classes).to include("text-xs")
    end

    context "with a registered theme that transforms labels active" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:midnight) do |t|
          t.label_transform = "uppercase tracking-wider"
        end
      end

      it "uses that theme's label transform" do
        expect(component.label_classes.split).to include("uppercase", "tracking-wider")
      end
    end
  end

  describe "#select_classes" do
    subject(:select_classes) { described_class.new(name: :status, options: options).select_classes.split }

    it "includes full width" do
      expect(select_classes).to include("w-full")
    end

    it "includes appearance-none" do
      expect(select_classes).to include("appearance-none")
    end

    it "uses the theme's border width" do
      expect(select_classes).to include("border")
    end

    it "includes text-sm" do
      expect(select_classes).to include("text-sm")
    end

    it "draws the chevron with the engine's cp-select-chevron class" do
      expect(select_classes).to include("cp-select-chevron")
    end
  end

  describe "rendered select" do
    subject(:select) { render_inline(described_class.new(name: :status, options: options)).at_css("select") }

    it "has no inline style, so no chevron color is fixed in the markup" do
      expect(select[:style]).to be_nil
    end

    it "uses the select classes" do
      expect(select[:class].split).to include("cp-select-chevron", "h-9")
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
