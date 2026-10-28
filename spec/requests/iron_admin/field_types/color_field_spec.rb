# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Color field type", type: :request do
  let(:page) { response.parsed_body }
  let(:picker) { page.at_css("input[type=color]") }
  let(:hex_input) { page.at_css("input[type=text]#record_color_hex") }

  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::ProfileResource)
  end

  describe "GET /:resource_name/new" do
    before { get iron_admin.new_resource_path("profiles"), as: :html }

    it "submits a single value under the field name" do
      expect(page.css("[name='record[color_hex]']").size).to eq(1)
    end

    it "submits the hex text input" do
      expect(hex_input["name"]).to eq("record[color_hex]")
    end

    it "leaves the color picker out of the submitted params" do
      expect(picker.attributes).not_to have_key("name")
    end

    it "gives the color picker its own id" do
      expect(page.css("#record_color_hex").size).to eq(1)
    end

    it "gives the color picker the shadow of the hex input next to it" do
      expect(picker[:class].split).to include(*IronAdmin.current_theme.control_shadow.split)
    end

    it "labels the color picker for assistive technology" do
      expect(picker["aria-label"]).to eq("Color hex picker")
    end

    it "connects the picker and the hex input to the color field controller" do
      targets = page.css("[data-controller=cp-color-field] [data-cp-color-field-target]")

      expect(targets.pluck("data-cp-color-field-target")).to eq(%w[picker text])
    end

    it "explains the expected format when the hex input is rejected" do
      expect(hex_input["title"]).to eq("Enter a hex color such as #1a2b3c or #abc.")
    end

    describe "hex input pattern" do
      # Browsers anchor the pattern attribute to the whole value.
      subject(:pattern) { Regexp.new("\\A(?:#{hex_input["pattern"]})\\z") }

      it "accepts six-digit hex colors" do
        expect(pattern).to match("#1A2b3c")
      end

      it "accepts three-digit hex colors" do
        expect(pattern).to match("#abc")
      end

      it "rejects text that is not a hex color" do
        expect(pattern).not_to match("#12345")
      end
    end
  end

  describe "GET /:resource_name/:id/edit" do
    before do
      get iron_admin.edit_resource_path("profiles", create(:profile, color_hex: "#10b981")), as: :html
    end

    it "shows the stored color in the picker" do
      expect(picker["value"]).to eq("#10b981")
    end

    it "shows the stored color in the hex input" do
      expect(hex_input["value"]).to eq("#10b981")
    end
  end

  describe "PATCH /:resource_name/:id" do
    it "saves the submitted hex value" do
      profile = create(:profile, color_hex: "#10b981")

      patch iron_admin.resource_path("profiles", profile), params: { record: { color_hex: "#ff0000" } }, as: :html

      expect(profile.reload.color_hex).to eq("#ff0000")
    end
  end
end
