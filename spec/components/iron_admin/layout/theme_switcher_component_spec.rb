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

    expect(swatches).to match([include("bg-white", "ring-zinc-300"), include("bg-zinc-950", "ring-zinc-700")])
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
