require "rails_helper"
require_relative "../../../../app/components/iron_admin/form/checkbox_component"

RSpec.describe IronAdmin::Form::CheckboxComponent, type: :component do
  describe "#initialize" do
    it "requires name" do
      component = described_class.new(name: :active)
      expect(component.name).to eq(:active)
    end

    it "defaults checked to false" do
      component = described_class.new(name: :active)
      expect(component.checked).to be false
    end

    it "defaults disabled to false" do
      component = described_class.new(name: :active)
      expect(component.disabled).to be false
    end

    it "accepts label" do
      component = described_class.new(name: :active, label: "Is active")
      expect(component.label).to eq("Is active")
    end
  end

  describe "#checkbox_classes" do
    it "includes h-4 w-4" do
      component = described_class.new(name: :active)
      expect(component.checkbox_classes).to include("h-4")
      expect(component.checkbox_classes).to include("w-4")
    end

    it "uses the theme's checkbox_radius" do
      component = described_class.new(name: :active)
      expect(component.checkbox_classes.split).to include(IronAdmin.current_theme.checkbox_radius)
    end

    it "uses the theme's checkbox_border and checked state" do
      theme = IronAdmin.current_theme
      component = described_class.new(name: :active)
      expect(component.checkbox_classes.split).to include(theme.checkbox_border, *theme.checkbox_checked.split)
    end

    it "draws the engine's check mark" do
      component = described_class.new(name: :active)
      expect(component.checkbox_classes.split).to include("appearance-none", "cp-checkbox-mark")
    end
  end

  describe "field readonly enforcement" do
    let(:user) { double("User") }

    context "when field is readonly for user" do
      let(:field) { IronAdmin::Field.new(:active, readonly: true) }

      it "renders disabled checkbox" do
        result = render_inline(described_class.new(name: :active, field: field, current_user: user))
        expect(result.css("input[type='checkbox'][disabled]")).to be_present
      end
    end

    context "when field uses proc for readonly" do
      let(:admin_user) { double("User", admin?: true) }
      let(:regular_user) { double("User", admin?: false) }
      let(:field) { IronAdmin::Field.new(:active, readonly: ->(user) { !user.admin? }) }

      it "renders disabled checkbox for non-admin" do
        result = render_inline(described_class.new(name: :active, field: field, current_user: regular_user))
        expect(result.css("input[type='checkbox'][disabled]")).to be_present
      end

      it "renders enabled checkbox for admin" do
        result = render_inline(described_class.new(name: :active, field: field, current_user: admin_user))
        expect(result.css("input[type='checkbox'][disabled]")).not_to be_present
      end
    end

    context "when field is not readonly" do
      let(:field) { IronAdmin::Field.new(:active, readonly: false) }

      it "renders enabled checkbox" do
        result = render_inline(described_class.new(name: :active, field: field, current_user: user))
        expect(result.css("input[type='checkbox'][disabled]")).not_to be_present
      end
    end

    context "when no field is provided" do
      it "uses disabled parameter only" do
        result = render_inline(described_class.new(name: :active, disabled: false))
        expect(result.css("input[type='checkbox'][disabled]")).not_to be_present
      end
    end
  end

  context "with a registered theme active" do
    before do
      IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:blocky) do |theme|
        theme.control_radius = "rounded-none"
        theme.checkbox_radius = "rounded-none"
      end
    end

    it "renders the checkbox with that theme's radius" do
      expect(render_inline(described_class.new(name: :active)).at_css("input[type='checkbox']")[:class].split).to include("rounded-none")
    end
  end
end
