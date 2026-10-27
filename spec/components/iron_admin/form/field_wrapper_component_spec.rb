require "rails_helper"
require_relative "../../../../app/components/iron_admin/form/field_wrapper_component"

RSpec.describe IronAdmin::Form::FieldWrapperComponent, type: :component do
  describe "#initialize" do
    it "stores name" do
      component = described_class.new(name: :email)
      expect(component.name).to eq(:email)
    end

    it "generates label from name when not provided" do
      component = described_class.new(name: :user_email)
      expect(component.label).to eq("User email")
    end

    it "accepts custom label" do
      component = described_class.new(name: :email, label: "Email Address")
      expect(component.label).to eq("Email Address")
    end

    it "defaults errors to empty array" do
      component = described_class.new(name: :email)
      expect(component.errors).to eq([])
    end

    it "converts single error to array" do
      component = described_class.new(name: :email, errors: "is invalid")
      expect(component.errors).to eq(["is invalid"])
    end

    it "defaults required to false" do
      component = described_class.new(name: :email)
      expect(component.required).to be false
    end

    it "defaults hint to nil" do
      component = described_class.new(name: :email)
      expect(component.hint).to be_nil
    end

    it "defaults span_full to false" do
      component = described_class.new(name: :email)
      expect(component.span_full).to be false
    end

    it "accepts all options" do
      component = described_class.new(
        name: :email,
        label: "Email",
        errors: ["is invalid"],
        required: true,
        hint: "Enter your email",
        span_full: true
      )
      expect(component.required).to be true
      expect(component.hint).to eq("Enter your email")
      expect(component.span_full).to be true
    end
  end

  describe "#has_errors?" do
    it "returns false when errors are empty" do
      component = described_class.new(name: :email)
      expect(component.has_errors?).to be false
    end

    it "returns true when errors exist" do
      component = described_class.new(name: :email, errors: ["is invalid"])
      expect(component.has_errors?).to be true
    end
  end

  describe "#wrapper_classes" do
    it "returns empty string when span_full is false" do
      component = described_class.new(name: :email, span_full: false)
      expect(component.wrapper_classes).to eq("")
    end

    it "returns span classes when span_full is true" do
      component = described_class.new(name: :email, span_full: true)
      expect(component.wrapper_classes).to include("md:col-span-2")
    end
  end

  describe "#label_classes" do
    it "includes text-sm" do
      component = described_class.new(name: :email)
      expect(component.label_classes).to include("text-sm")
    end

    it "includes font-medium" do
      component = described_class.new(name: :email)
      expect(component.label_classes).to include("font-medium")
    end

    it "includes mb-1.5" do
      component = described_class.new(name: :email)
      expect(component.label_classes).to include("mb-1.5")
    end
  end

  describe "#error_classes" do
    it "includes flex layout" do
      component = described_class.new(name: :email)
      expect(component.error_classes).to include("flex")
    end

    it "includes mt-1.5" do
      component = described_class.new(name: :email)
      expect(component.error_classes).to include("mt-1.5")
    end
  end

  describe "rendering" do
    let(:theme) { IronAdmin.current_theme }

    context "when required" do
      subject(:mark) { render_inline(described_class.new(name: :email, required: true)) { "input" }.at_css("label span") }

      it "writes the required mark in the theme's error color" do
        expect(mark[:class].split).to include(theme.error_text)
      end
    end

    context "with errors" do
      subject(:result) { render_inline(described_class.new(name: :email, errors: ["is invalid"])) { "input" } }

      it "writes the message in the theme's error color" do
        expect(result.at_css("p")[:class].split).to include(theme.error_text)
      end

      it "draws the icon in the theme's error color" do
        expect(result.at_css("svg")[:class].split).to include(theme.error_text)
      end
    end
  end
end
