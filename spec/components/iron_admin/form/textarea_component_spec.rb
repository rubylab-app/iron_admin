require "rails_helper"
require_relative "../../../../app/components/iron_admin/form/textarea_component"

RSpec.describe IronAdmin::Form::TextareaComponent, type: :component do
  describe "#initialize" do
    it "stores name" do
      component = described_class.new(name: :description)
      expect(component.name).to eq(:description)
    end

    it "defaults value to nil" do
      component = described_class.new(name: :description)
      expect(component.value).to be_nil
    end

    it "defaults rows to 4" do
      component = described_class.new(name: :description)
      expect(component.rows).to eq(4)
    end

    it "generates placeholder from name" do
      component = described_class.new(name: :user_bio)
      expect(component.placeholder).to eq("User bio")
    end

    it "accepts custom placeholder" do
      component = described_class.new(name: :description, placeholder: "Enter description...")
      expect(component.placeholder).to eq("Enter description...")
    end

    it "defaults disabled to false" do
      component = described_class.new(name: :description)
      expect(component.disabled).to be false
    end

    it "defaults readonly to false" do
      component = described_class.new(name: :description)
      expect(component.readonly).to be false
    end

    it "defaults has_error to false" do
      component = described_class.new(name: :description)
      expect(component.has_error).to be false
    end
  end

  describe "#textarea_classes" do
    it "includes w-full" do
      component = described_class.new(name: :description)
      expect(component.textarea_classes).to include("w-full")
    end

    it "includes border" do
      component = described_class.new(name: :description)
      expect(component.textarea_classes).to include("border")
    end

    it "includes resize-y" do
      component = described_class.new(name: :description)
      expect(component.textarea_classes).to include("resize-y")
    end

    it "uses the theme's input_error when has_error" do
      component = described_class.new(name: :description, has_error: true)
      expect(component.textarea_classes.split).to include(*IronAdmin.current_theme.input_error.split)
    end

    it "drops the theme's input_border when has_error" do
      component = described_class.new(name: :description, has_error: true)
      expect(component.textarea_classes.split).not_to include(*IronAdmin.current_theme.input_border.split)
    end

    it "uses the theme's surface_muted when readonly" do
      component = described_class.new(name: :description, readonly: true)
      expect(component.textarea_classes.split).to include(IronAdmin.current_theme.surface_muted)
    end

    it "includes disabled classes when disabled" do
      component = described_class.new(name: :description, disabled: true)
      expect(component.textarea_classes).to include("cursor-not-allowed")
    end

    it "includes disabled classes when readonly" do
      component = described_class.new(name: :description, readonly: true)
      expect(component.textarea_classes).to include("cursor-not-allowed")
    end
  end

  describe "#call" do
    it "renders a textarea element" do
      result = render_inline(described_class.new(name: :description))
      expect(result.css("textarea")).to be_present
    end

    it "renders with value" do
      result = render_inline(described_class.new(name: :description, value: "Test content"))
      expect(result.css("textarea").text).to eq("Test content")
    end

    it "renders with rows attribute" do
      result = render_inline(described_class.new(name: :description, rows: 6))
      expect(result.css("textarea[rows='6']")).to be_present
    end

    it "renders disabled textarea" do
      result = render_inline(described_class.new(name: :description, disabled: true))
      expect(result.css("textarea[disabled]")).to be_present
    end

    it "renders readonly textarea" do
      result = render_inline(described_class.new(name: :description, readonly: true))
      expect(result.css("textarea[readonly]")).to be_present
    end
  end

  describe "field readonly enforcement" do
    let(:user) { double("User") }

    context "when field is readonly for user" do
      let(:field) { IronAdmin::Field.new(:description, readonly: true) }

      it "renders disabled textarea" do
        result = render_inline(described_class.new(name: :description, field: field, current_user: user))
        expect(result.css("textarea[disabled]")).to be_present
      end

      it "includes disabled classes" do
        component = described_class.new(name: :description, field: field, current_user: user)
        expect(component.textarea_classes).to include("cursor-not-allowed")
      end
    end

    context "when field uses proc for readonly" do
      let(:admin_user) { double("User", admin?: true) }
      let(:regular_user) { double("User", admin?: false) }
      let(:field) { IronAdmin::Field.new(:description, readonly: ->(user) { !user.admin? }) }

      it "renders disabled textarea for non-admin" do
        result = render_inline(described_class.new(name: :description, field: field, current_user: regular_user))
        expect(result.css("textarea[disabled]")).to be_present
      end

      it "renders enabled textarea for admin" do
        result = render_inline(described_class.new(name: :description, field: field, current_user: admin_user))
        expect(result.css("textarea[disabled]")).not_to be_present
      end
    end

    context "when field is not readonly" do
      let(:field) { IronAdmin::Field.new(:description, readonly: false) }

      it "renders enabled textarea" do
        result = render_inline(described_class.new(name: :description, field: field, current_user: user))
        expect(result.css("textarea[disabled]")).not_to be_present
      end
    end

    context "when no field is provided" do
      it "uses disabled parameter only" do
        result = render_inline(described_class.new(name: :description, disabled: false))
        expect(result.css("textarea[disabled]")).not_to be_present
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

    it "renders the textarea with that theme's radius" do
      expect(render_inline(described_class.new(name: :description)).at_css("textarea")[:class].split).to include("rounded-none")
    end
  end
end
