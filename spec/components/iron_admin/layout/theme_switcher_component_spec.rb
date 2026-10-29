# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Layout::ThemeSwitcherComponent, type: :component do
  subject(:rendered) do
    with_controller_class(IronAdmin::ResourcesController) do
      with_request_url("/admin/users?page=2") do
        render_inline(described_class.new(themes: themes, current_theme: current_theme))
      end
    end
  end

  let(:midnight) do
    IronAdmin.configuration.register_theme(:midnight) { |t| t.swatch = "bg-zinc-950 ring-1 ring-inset ring-zinc-700" }
  end
  let(:themes) { [IronAdmin.configuration.theme, midnight] }
  let(:current_theme) { midnight }
  let(:form) { rendered.at_css("details form") }
  let(:buttons) { form.css("button[type='submit'][name='theme']") }

  it "is a disclosure the cp-disclosure controller closes" do
    expect(rendered.at_css("details")["data-controller"]).to eq("cp-disclosure")
  end

  it "names the disclosure after the current theme" do
    expect(rendered.at_css("details > summary").text.squish).to eq("Theme: Midnight")
  end

  it "shows a swatch icon in the summary" do
    expect(rendered.at_css("details > summary svg")).to be_present
  end

  it "posts the choice to the theme switch endpoint" do
    expect([form[:method], form[:action]]).to eq(["post", theme_path])
  end

  it "reloads the whole page, so the html element, fonts and color scheme change too" do
    expect(form["data-turbo"]).to eq("false")
  end

  it "names the list of themes" do
    expect(form["aria-label"]).to eq("Themes")
  end

  it "returns to the current page" do
    expect(form.at_css("input[type='hidden'][name='return_to']")[:value]).to eq("/admin/users?page=2")
  end

  it "has a button per theme" do
    expect(buttons.map { |button| [button[:value], button.text.squish] }).to eq([%w[neutral Neutral], %w[midnight Midnight]])
  end

  it "presses the current theme's button only" do
    expect(buttons.pluck("aria-pressed")).to eq(%w[false true])
  end

  it "draws each theme's swatch" do
    swatches = buttons.map { |button| button.at_css("span[aria-hidden='true']")[:class].split }

    expect(swatches).to match([include("bg-white", "ring-zinc-500/80"), include("bg-zinc-950", "ring-zinc-700")])
  end

  it "rounds Neutral's swatch with its own classes" do
    expect(buttons.first.at_css("span[aria-hidden='true']")[:class].split).to include("rounded-full")
  end

  it "takes the shape of each swatch from its theme" do
    expect(buttons.last.at_css("span[aria-hidden='true']")[:class].split).not_to include("rounded-full")
  end

  describe "styles" do
    let(:summary) { rendered.at_css("details > summary")[:class].split }
    let(:panel) { rendered.at_css("details > div")[:class].split }
    let(:option) { buttons.first[:class].split }
    let(:check) { buttons.last.at_css("svg") }

    context "with the default theme current" do
      let(:current_theme) { IronAdmin.configuration.theme }

      it "draws the summary as a ghost icon button" do
        expect(summary).to include("h-9", "w-9", "rounded-md", "hover:bg-zinc-100", "focus-visible:outline-indigo-500")
      end

      it "draws the panel as a dropdown surface lifted by the theme's popover_shadow" do
        expect(panel).to include("bg-white", "border", "border-zinc-200", "rounded-lg", "shadow-lg")
      end

      it "highlights a hovered theme with the theme's item_hover" do
        expect(option).to include("hover:bg-zinc-100", "rounded-md")
      end
    end

    context "with a registered theme current" do
      let(:midnight) do
        IronAdmin.configuration.register_theme(:midnight) do |t|
          t.card_bg = "bg-zinc-900"
          t.card_border = "border-zinc-800"
          t.popover_shadow = "shadow-2xl"
          t.item_hover = "hover:bg-zinc-800"
        end
      end

      it "draws the panel with that theme" do
        expect(panel).to include("bg-zinc-900", "border-zinc-800", "shadow-2xl")
      end

      it "highlights a hovered theme with that theme's item_hover" do
        expect(option).to include("hover:bg-zinc-800")
      end
    end

    context "with a current theme that sets popover_bg" do
      let(:midnight) do
        IronAdmin.configuration.register_theme(:midnight) do |t|
          t.card_bg = "bg-zinc-900"
          t.popover_bg = "bg-zinc-800"
        end
      end

      it "draws the panel on popover_bg" do
        expect(panel).to include("bg-zinc-800")
      end

      it "does not draw it on card_bg" do
        expect(panel).not_to include("bg-zinc-900")
      end
    end

    it "checks the current theme in the row's own text color" do
      expect(check[:class].split).not_to include("text-zinc-400")
    end

    it "hides the check from screen readers, which read aria-pressed" do
      expect(check["aria-hidden"]).to eq("true")
    end
  end

  context "with forgery protection on" do
    around do |example|
      original = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      example.run
    ensure
      ActionController::Base.allow_forgery_protection = original
    end

    it "sends the CSRF token" do
      expect(form.at_css("input[type='hidden'][name='authenticity_token']")[:value]).to be_present
    end
  end

  context "with one theme" do
    let(:themes) { [IronAdmin.configuration.theme] }
    let(:current_theme) { IronAdmin.configuration.theme }

    it "renders nothing" do
      expect(rendered.to_html).to be_empty
    end
  end
end
