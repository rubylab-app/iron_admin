require "rails_helper"
require_relative "../../../../app/components/iron_admin/form/text_input_component"

RSpec.describe IronAdmin::Form::TextInputComponent, type: :component do
  describe "#initialize" do
    it "requires name" do
      component = described_class.new(name: :email)
      expect(component.name).to eq(:email)
    end

    it "defaults type to text" do
      component = described_class.new(name: :email)
      expect(component.type).to eq(:text)
    end

    it "defaults disabled to false" do
      component = described_class.new(name: :email)
      expect(component.disabled).to be false
    end

    it "defaults readonly to false" do
      component = described_class.new(name: :email)
      expect(component.readonly).to be false
    end

    it "defaults has_error to false" do
      component = described_class.new(name: :email)
      expect(component.has_error).to be false
    end

    it "generates placeholder from name" do
      component = described_class.new(name: :user_email)
      expect(component.placeholder).to eq("User email")
    end
  end

  describe "#input_classes" do
    it "includes border class" do
      component = described_class.new(name: :email)
      expect(component.input_classes).to include("border")
    end

    it "uses the theme's input_error when has_error" do
      component = described_class.new(name: :email, has_error: true)
      expect(component.input_classes.split).to include(*IronAdmin.current_theme.input_error.split)
    end

    it "drops the theme's input_border when has_error" do
      component = described_class.new(name: :email, has_error: true)
      expect(component.input_classes.split).not_to include(*IronAdmin.current_theme.input_border.split)
    end

    it "uses the theme's surface_muted when readonly" do
      component = described_class.new(name: :email, readonly: true)
      expect(component.input_classes.split).to include(IronAdmin.current_theme.surface_muted)
    end

    it "is 36px high" do
      expect(described_class.new(name: :email).input_classes.split).to include("h-9")
    end

    it "includes disabled classes when disabled" do
      component = described_class.new(name: :email, disabled: true)
      expect(component.input_classes).to include("cursor-not-allowed")
    end
  end

  describe "#call" do
    it "renders an input element" do
      result = render_inline(described_class.new(name: :email, value: "test@example.com"))
      expect(result.css("input[type='text']")).to be_present
      expect(result.css("input[value='test@example.com']")).to be_present
    end

    it "renders disabled input" do
      result = render_inline(described_class.new(name: :email, disabled: true))
      expect(result.css("input[disabled]")).to be_present
    end
  end

  describe "field readonly enforcement" do
    let(:user) { double("User") }

    context "when field is readonly for user" do
      let(:field) { IronAdmin::Field.new(:email, readonly: true) }

      it "renders disabled input" do
        result = render_inline(described_class.new(name: :email, field: field, current_user: user))
        expect(result.css("input[disabled]")).to be_present
      end

      it "includes disabled classes" do
        component = described_class.new(name: :email, field: field, current_user: user)
        expect(component.input_classes).to include("cursor-not-allowed")
      end
    end

    context "when field uses proc for readonly" do
      let(:admin_user) { double("User", admin?: true) }
      let(:regular_user) { double("User", admin?: false) }
      let(:field) { IronAdmin::Field.new(:email, readonly: ->(user) { !user.admin? }) }

      it "renders disabled input for non-admin" do
        result = render_inline(described_class.new(name: :email, field: field, current_user: regular_user))
        expect(result.css("input[disabled]")).to be_present
      end

      it "renders enabled input for admin" do
        result = render_inline(described_class.new(name: :email, field: field, current_user: admin_user))
        expect(result.css("input[disabled]")).not_to be_present
      end
    end

    context "when field is not readonly" do
      let(:field) { IronAdmin::Field.new(:email, readonly: false) }

      it "renders enabled input" do
        result = render_inline(described_class.new(name: :email, field: field, current_user: user))
        expect(result.css("input[disabled]")).not_to be_present
      end
    end

    context "when no field is provided" do
      it "uses disabled parameter only" do
        result = render_inline(described_class.new(name: :email, disabled: false))
        expect(result.css("input[disabled]")).not_to be_present
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

    it "renders the input with that theme's radius" do
      expect(render_inline(described_class.new(name: :email)).at_css("input")[:class].split).to include("rounded-none")
    end
  end
end
