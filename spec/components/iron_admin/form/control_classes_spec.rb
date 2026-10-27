# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Form::ControlClasses do
  let(:theme) { IronAdmin::Configuration::Theme.new }

  # Classes of +property+ that no other state of the control shares.
  def own_classes(property, *others)
    theme.public_send(property).split - others.flat_map { |other| theme.public_send(other).split }
  end

  shared_examples "a themed field box" do
    it "takes the radius, border width and shadow from the theme" do
      expect(classes).to include(theme.control_radius, theme.border_width, theme.control_shadow)
    end

    it "takes the text color from the theme" do
      expect(classes).to include(theme.body_text)
    end

    it "takes the border color and the focus state from the theme" do
      expect(classes).to include(*theme.input_border.split, *theme.input_focus.split)
    end

    it "takes the background from the theme" do
      expect(classes).to include(theme.card_bg)
    end

    context "with an error" do
      let(:options) { { error: true } }

      it "uses input_error" do
        expect(classes).to include(*theme.input_error.split)
      end

      it "drops the input_border and input_focus classes that input_error replaces" do
        expect(classes & (own_classes(:input_border, :input_error) + own_classes(:input_focus, :input_error))).to be_empty
      end
    end
  end

  shared_examples "a themed field box that can be muted" do
    context "when muted (readonly or disabled)" do
      let(:options) { { muted: true } }

      it "uses surface_muted" do
        expect(classes).to include(theme.surface_muted, "cursor-not-allowed")
      end

      it "drops card_bg, which surface_muted replaces" do
        expect(classes).not_to include(theme.card_bg)
      end
    end
  end

  describe ".input" do
    subject(:classes) { described_class.input(theme, **options).split }

    let(:options) { {} }

    it_behaves_like "a themed field box"
    it_behaves_like "a themed field box that can be muted"

    it "is 36px high" do
      expect(classes).to include("h-9")
    end

    it "pads both sides by default" do
      expect(classes).to include("px-3")
    end

    it "takes the placeholder color from the theme" do
      expect(classes).to include(theme.placeholder_text)
    end

    context "with a padding" do
      let(:options) { { padding: "pl-9 pr-3" } }

      it "uses it" do
        expect(classes).to include("pl-9", "pr-3")
      end

      it "drops the default padding" do
        expect(classes).not_to include("px-3")
      end
    end
  end

  describe ".textarea" do
    subject(:classes) { described_class.textarea(theme, **options).split }

    let(:options) { {} }

    it_behaves_like "a themed field box"
    it_behaves_like "a themed field box that can be muted"

    it "can be resized vertically" do
      expect(classes).to include("resize-y")
    end

    it "grows with its rows instead of a fixed height" do
      expect(classes).not_to include("h-9")
    end

    it "takes the placeholder color from the theme" do
      expect(classes).to include(theme.placeholder_text)
    end
  end

  describe ".select" do
    subject(:classes) { described_class.select(theme, **options).split }

    let(:options) { {} }

    it_behaves_like "a themed field box"
    it_behaves_like "a themed field box that can be muted"

    it "is 36px high" do
      expect(classes).to include("h-9")
    end

    it "draws the engine's chevron and leaves room for it" do
      expect(classes).to include("appearance-none", "cp-select-chevron", "pr-9")
    end
  end

  describe ".file_input" do
    subject(:classes) { described_class.file_input(theme, **options).split }

    let(:options) { {} }

    it_behaves_like "a themed field box"

    it "is 36px high" do
      expect(classes).to include("h-9")
    end

    it "separates the file button with the input's own border color" do
      expect(classes).to include("file:border-r", "file:border-inherit")
    end
  end

  describe ".checkbox" do
    subject(:classes) { described_class.checkbox(theme).split }

    it "takes the radius and the border from the theme" do
      expect(classes).to include(theme.checkbox_radius, theme.border_width, theme.checkbox_border)
    end

    it "takes the checked state from the theme" do
      expect(classes).to include(*theme.checkbox_checked.split)
    end

    it "draws the engine's check mark" do
      expect(classes).to include("appearance-none", "cp-checkbox-mark")
    end

    it "leaves out input_border, whose hover color would cover the checked border" do
      expect(classes & own_classes(:input_border, :checkbox_border)).to be_empty
    end
  end

  describe ".radio" do
    subject(:classes) { described_class.radio(theme).split }

    it "is round" do
      expect(classes).to include("rounded-full")
    end

    it "ignores the checkbox radius" do
      expect(classes).not_to include(theme.checkbox_radius)
    end

    it "takes the border and the checked state from the theme" do
      expect(classes).to include(theme.checkbox_border, *theme.checkbox_checked.split)
    end

    it "draws the engine's dot" do
      expect(classes).to include("appearance-none", "cp-radio-mark")
    end
  end

  describe ".button" do
    subject(:classes) { described_class.button(theme, variant).split }

    let(:variant) { :primary }

    it "is 36px high with the Neutral padding and type" do
      expect(classes).to include("h-9", "px-3.5", "text-sm", "font-medium")
    end

    it "takes the radius from the theme" do
      expect(classes).to include(theme.control_radius)
    end

    context "with :primary" do
      it "uses btn_primary, which carries its own focus outline, and the control shadow" do
        expect(classes).to include(*theme.btn_primary.split, theme.control_shadow)
      end
    end

    {
      secondary: :btn_secondary,
      danger: :btn_danger,
    }.each do |name, property|
      context "with :#{name}" do
        let(:variant) { name }

        it "uses #{property}, the control shadow and the focus ring" do
          expect(classes).to include(*theme.public_send(property).split, theme.control_shadow, *theme.focus_ring.split)
        end
      end
    end

    context "with :ghost" do
      let(:variant) { :ghost }

      it "uses btn_ghost and the focus ring" do
        expect(classes).to include(*theme.btn_ghost.split, *theme.focus_ring.split)
      end

      it "stays flat" do
        expect(classes).not_to include(theme.control_shadow)
      end
    end

    context "with an unknown variant" do
      let(:variant) { :loud }

      it "raises ArgumentError" do
        expect { classes }.to raise_error(ArgumentError, /loud/)
      end
    end
  end

  context "with a registered theme" do
    let(:theme) do
      IronAdmin.configuration.register_theme(:blocky) do |blocky|
        blocky.control_radius = "rounded-none"
        blocky.border_width = "border-2"
        blocky.control_shadow = "shadow-[2px_2px_0_0_currentColor]"
      end
    end

    it "builds inputs from its classes" do
      expect(described_class.input(theme).split).to include("rounded-none", "border-2", "shadow-[2px_2px_0_0_currentColor]")
    end

    it "builds buttons from its classes" do
      expect(described_class.button(theme, :secondary).split).to include("rounded-none")
    end
  end

  context "with a theme without a control shadow" do
    before { theme.control_shadow = "" }

    it "leaves no blank class" do
      expect(described_class.input(theme)).not_to match(/\s{2}/)
    end
  end
end
