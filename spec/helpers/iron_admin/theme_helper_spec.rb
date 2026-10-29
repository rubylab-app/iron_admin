# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::ThemeHelper, type: :helper do
  let(:controls) { IronAdmin::Form::ControlClasses }
  let(:theme) { helper.t }

  describe "#t" do
    context "outside a request" do
      it "returns the default theme" do
        expect(helper.t).to equal(IronAdmin.configuration.theme)
      end
    end

    context "when the request resolved a theme" do
      let(:midnight) { IronAdmin.configuration.register_theme(:midnight) }

      before { IronAdmin::RequestContext.theme = midnight }

      it "returns that theme" do
        expect(helper.t).to equal(midnight)
      end
    end
  end

  {
    cp_btn_primary: :primary,
    cp_btn_primary_lg: :primary,
    cp_btn_filter_apply: :primary,
    cp_btn_secondary: :secondary,
    cp_btn_danger: :danger,
    cp_btn_ghost: :ghost,
  }.each do |method, variant|
    describe "##{method}" do
      it "returns the theme's #{variant} button" do
        expect(helper.public_send(method)).to eq(controls.button(theme, variant))
      end
    end
  end

  {
    cp_input_class: :input,
    cp_select_class: :select,
    cp_textarea_class: :textarea,
    cp_file_input_class: :file_input,
  }.each do |method, control|
    describe "##{method}" do
      it "returns the theme's #{control} classes" do
        expect(helper.public_send(method)).to eq(controls.public_send(control, theme))
      end

      context "with an error" do
        it "returns the error state" do
          expect(helper.public_send(method, error: true)).to eq(controls.public_send(control, theme, error: true))
        end
      end
    end
  end

  describe "#cp_input_class with a padding" do
    it "uses that padding" do
      expect(helper.cp_input_class(padding: "pl-7 pr-3")).to eq(controls.input(theme, padding: "pl-7 pr-3"))
    end
  end

  describe "#cp_filter_input_class" do
    it "returns a theme text input" do
      expect(helper.cp_filter_input_class).to eq(controls.input(theme))
    end
  end

  describe "#cp_search_class" do
    it "returns a theme text input with room for the search icon" do
      expect(helper.cp_search_class).to eq(controls.input(theme, padding: "pl-9 pr-3"))
    end
  end

  describe "#cp_checkbox_class" do
    it "returns the theme's checkbox" do
      expect(helper.cp_checkbox_class).to eq(controls.checkbox(theme))
    end
  end

  describe "#cp_radio_class" do
    it "returns the theme's radio button" do
      expect(helper.cp_radio_class).to eq(controls.radio(theme))
    end
  end

  describe "#cp_navbar_search_class" do
    subject(:classes) { helper.cp_navbar_search_class.split }

    it "uses the navbar search backgrounds" do
      expect(classes).to include(theme.navbar_search_bg, theme.navbar_search_focus_bg)
    end

    it "uses the theme's control radius and placeholder color" do
      expect(classes).to include(theme.control_radius, theme.placeholder_text)
    end

    it "leaves out card_bg, which navbar_search_bg replaces" do
      expect(classes).not_to include(theme.card_bg)
    end

    it "casts the theme's control shadow, like every input" do
      expect(classes).to include(theme.control_shadow)
    end
  end

  describe "#cp_badge_count" do
    it "uses the theme's badge shape and counter colors" do
      expect(helper.cp_badge_count.split).to include(*theme.badge_shape.split, *theme.badge_count.split)
    end
  end

  describe "#cp_card" do
    it "uses the theme's card background, border, radius and shadow" do
      expect(helper.cp_card.split)
        .to include(theme.card_bg, theme.border_width, theme.card_border, theme.border_radius, theme.card_shadow)
    end
  end

  describe "#cp_heading" do
    it "uses the theme's heading weight and font family" do
      expect(helper.cp_heading.split).to include(theme.heading_weight, theme.font_family)
    end

    context "with a heading font" do
      before { theme.heading_font = "font-serif" }

      it "uses it" do
        expect(helper.cp_heading.split).to include("font-serif")
      end

      it "drops the body font family" do
        expect(helper.cp_heading.split).not_to include(theme.font_family)
      end
    end
  end

  context "with a registered theme active" do
    before do
      IronAdmin::RequestContext.theme = IronAdmin.configuration.register_theme(:blocky) do |blocky|
        blocky.btn_primary = "bg-black text-white"
        blocky.control_radius = "rounded-none"
      end
    end

    it "builds buttons from its classes" do
      expect(helper.cp_btn_primary.split).to include("bg-black", "rounded-none")
    end

    it "builds inputs from its classes" do
      expect(helper.cp_input_class.split).to include("rounded-none")
    end
  end
end
