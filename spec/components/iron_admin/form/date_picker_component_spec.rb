require "rails_helper"
require_relative "../../../../app/components/iron_admin/form/date_picker_component"

RSpec.describe IronAdmin::Form::DatePickerComponent, type: :component do
  describe "#initialize" do
    it "stores name" do
      component = described_class.new(name: :created_at)
      expect(component.name).to eq(:created_at)
    end

    it "defaults value to nil" do
      component = described_class.new(name: :created_at)
      expect(component.value).to be_nil
    end

    it "defaults type to datetime_local" do
      component = described_class.new(name: :created_at)
      expect(component.type).to eq(:datetime_local)
    end

    it "defaults disabled to false" do
      component = described_class.new(name: :created_at)
      expect(component.disabled).to be false
    end

    it "defaults has_error to false" do
      component = described_class.new(name: :created_at)
      expect(component.has_error).to be false
    end

    it "accepts all options" do
      component = described_class.new(
        name: :created_at,
        value: "2024-01-01",
        type: :date,
        min: "2020-01-01",
        max: "2030-12-31",
        disabled: true,
        has_error: true
      )
      expect(component.value).to eq("2024-01-01")
      expect(component.type).to eq(:date)
      expect(component.min).to eq("2020-01-01")
      expect(component.max).to eq("2030-12-31")
      expect(component.disabled).to be true
      expect(component.has_error).to be true
    end
  end

  describe "#input_type" do
    it "returns datetime-local for datetime_local type" do
      component = described_class.new(name: :created_at, type: :datetime_local)
      expect(component.input_type).to eq("datetime-local")
    end

    it "returns datetime-local for datetime type" do
      component = described_class.new(name: :created_at, type: :datetime)
      expect(component.input_type).to eq("datetime-local")
    end

    it "returns date for date type" do
      component = described_class.new(name: :created_at, type: :date)
      expect(component.input_type).to eq("date")
    end

    it "returns time for time type" do
      component = described_class.new(name: :created_at, type: :time)
      expect(component.input_type).to eq("time")
    end
  end

  describe "#input_classes" do
    it "includes border" do
      component = described_class.new(name: :created_at)
      expect(component.input_classes).to include("border")
    end

    it "includes w-full" do
      component = described_class.new(name: :created_at)
      expect(component.input_classes).to include("w-full")
    end

    it "uses the theme's input_error when has_error" do
      component = described_class.new(name: :created_at, has_error: true)
      expect(component.input_classes.split).to include(*IronAdmin.current_theme.input_error.split)
    end

    it "drops the theme's input_border when has_error" do
      component = described_class.new(name: :created_at, has_error: true)
      expect(component.input_classes.split).not_to include(*IronAdmin.current_theme.input_border.split)
    end

    it "uses the theme's surface_muted when disabled" do
      component = described_class.new(name: :created_at, disabled: true)
      expect(component.input_classes.split).to include(IronAdmin.current_theme.surface_muted)
    end

    it "includes disabled classes when disabled" do
      component = described_class.new(name: :created_at, disabled: true)
      expect(component.input_classes).to include("cursor-not-allowed")
    end
  end

  describe "#formatted_value" do
    it "returns nil when value is nil" do
      component = described_class.new(name: :created_at)
      expect(component.formatted_value).to be_nil
    end

    it "formats Date object for date type" do
      date = Date.new(2024, 6, 15)
      component = described_class.new(name: :created_at, value: date, type: :date)
      expect(component.formatted_value).to eq("2024-06-15")
    end

    it "formats DateTime object for datetime type" do
      datetime = DateTime.new(2024, 6, 15, 10, 30)
      component = described_class.new(name: :created_at, value: datetime, type: :datetime)
      expect(component.formatted_value).to eq("2024-06-15T10:30")
    end

    it "formats Time object for time type" do
      time = Time.zone.parse("10:30:00")
      component = described_class.new(name: :created_at, value: time, type: :time)
      expect(component.formatted_value).to eq("10:30")
    end

    it "returns string value as-is" do
      component = described_class.new(name: :created_at, value: "2024-06-15", type: :date)
      expect(component.formatted_value).to eq("2024-06-15")
    end
  end

  describe "#call" do
    it "renders an input element" do
      result = render_inline(described_class.new(name: :created_at))
      expect(result.css("input")).to be_present
    end

    it "renders with correct type attribute" do
      result = render_inline(described_class.new(name: :created_at, type: :date))
      expect(result.css("input[type='date']")).to be_present
    end

    it "renders disabled input" do
      result = render_inline(described_class.new(name: :created_at, disabled: true))
      expect(result.css("input[disabled]")).to be_present
    end
  end

  context "with a registered theme active" do
    before do
      IronAdmin::RequestContext.theme = IronAdmin.configuration.register_theme(:blocky) do |theme|
        theme.control_radius = "rounded-none"
        theme.checkbox_radius = "rounded-none"
      end
    end

    it "renders the input with that theme's radius" do
      expect(render_inline(described_class.new(name: :created_at)).at_css("input")[:class].split).to include("rounded-none")
    end
  end
end
