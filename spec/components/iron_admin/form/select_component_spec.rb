require "rails_helper"
require_relative "../../../../app/components/iron_admin/form/select_component"

RSpec.describe IronAdmin::Form::SelectComponent, type: :component do
  let(:options) { [%w[Active active], %w[Inactive inactive]] }

  describe "#initialize" do
    it "requires name and options" do
      component = described_class.new(name: :status, options: options)
      expect(component.name).to eq(:status)
      expect(component.options).to eq(options)
    end

    it "defaults include_blank to nil" do
      component = described_class.new(name: :status, options: options)
      expect(component.include_blank).to be_nil
    end

    it "defaults disabled to false" do
      component = described_class.new(name: :status, options: options)
      expect(component.disabled).to be false
    end

    it "accepts selected value" do
      component = described_class.new(name: :status, options: options, selected: "active")
      expect(component.selected).to eq("active")
    end
  end

  describe "#select_classes" do
    it "includes appearance-none" do
      component = described_class.new(name: :status, options: options)
      expect(component.select_classes).to include("appearance-none")
    end

    it "uses the theme's input_error when has_error" do
      component = described_class.new(name: :status, options: options, has_error: true)
      expect(component.select_classes.split).to include(*IronAdmin.current_theme.input_error.split)
    end

    it "drops the theme's input_border when has_error" do
      component = described_class.new(name: :status, options: options, has_error: true)
      expect(component.select_classes.split).not_to include(*IronAdmin.current_theme.input_border.split)
    end

    it "uses the theme's surface_muted when disabled" do
      component = described_class.new(name: :status, options: options, disabled: true)
      expect(component.select_classes.split).to include(IronAdmin.current_theme.surface_muted)
    end
  end

  describe "rendering" do
    subject(:select) { render_inline(described_class.new(name: :status, options: options)).at_css("select") }

    it "draws the engine's chevron, which follows the theme's color scheme" do
      expect(select[:class].split).to include("cp-select-chevron")
    end

    it "sets no inline style" do
      expect(select[:style]).to be_nil
    end
  end

  describe "field readonly enforcement" do
    let(:user) { double("User") }

    context "when field is readonly for user" do
      let(:field) { IronAdmin::Field.new(:status, readonly: true) }

      it "renders disabled select" do
        result = render_inline(described_class.new(name: :status, options: options, field: field, current_user: user))
        expect(result.css("select[disabled]")).to be_present
      end

      it "includes disabled classes" do
        component = described_class.new(name: :status, options: options, field: field, current_user: user)
        expect(component.select_classes).to include("cursor-not-allowed")
      end
    end

    context "when field uses proc for readonly" do
      let(:admin_user) { double("User", admin?: true) }
      let(:regular_user) { double("User", admin?: false) }
      let(:field) { IronAdmin::Field.new(:status, readonly: ->(user) { !user.admin? }) }

      it "renders disabled select for non-admin" do
        result = render_inline(described_class.new(name: :status, options: options, field: field, current_user: regular_user))
        expect(result.css("select[disabled]")).to be_present
      end

      it "renders enabled select for admin" do
        result = render_inline(described_class.new(name: :status, options: options, field: field, current_user: admin_user))
        expect(result.css("select[disabled]")).not_to be_present
      end
    end

    context "when field is not readonly" do
      let(:field) { IronAdmin::Field.new(:status, readonly: false) }

      it "renders enabled select" do
        result = render_inline(described_class.new(name: :status, options: options, field: field, current_user: user))
        expect(result.css("select[disabled]")).not_to be_present
      end
    end

    context "when no field is provided" do
      it "uses disabled parameter only" do
        result = render_inline(described_class.new(name: :status, options: options, disabled: false))
        expect(result.css("select[disabled]")).not_to be_present
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

    it "renders the select with that theme's radius" do
      expect(render_inline(described_class.new(name: :status, options: options)).at_css("select")[:class].split).to include("rounded-none")
    end
  end
end
