# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Form theme", type: :request do
  let(:document) { response.parsed_body }
  let(:theme) { IronAdmin.configuration.theme }
  let(:controls) { IronAdmin::Form::ControlClasses }

  def classes_at(selector)
    document.at_css(selector)[:class].split
  end

  describe "GET /:resource_name/new" do
    before { get iron_admin.new_resource_path("users"), as: :html }

    it "renders text inputs as theme inputs" do
      expect(classes_at("#record_name")).to eq(controls.input(theme).split)
    end

    it "renders the submit button as a theme primary button" do
      expect(classes_at("input[type=submit]")).to eq(controls.button(theme, :primary).split)
    end

    it "renders the cancel link as a theme secondary button" do
      expect(classes_at("a[href='#{iron_admin.resources_path("users")}']:not([data-turbo-frame])"))
        .to eq(controls.button(theme, :secondary).split)
    end
  end

  describe "POST /:resource_name with an invalid value" do
    before do
      post iron_admin.resources_path("users"), params: { record: { name: "", email: "kim@example.com" } }, as: :html
    end

    it "renders the invalid input in the theme's error state" do
      expect(classes_at("#record_name")).to eq(controls.input(theme, error: true).split)
    end

    it "leaves the valid input in its normal state" do
      expect(classes_at("#record_email")).to eq(controls.input(theme).split)
    end

    it "writes the message in the theme's error color" do
      message = document.css("p").find { |paragraph| paragraph.text.include?("can't be blank") }

      expect(message[:class].split).to include(theme.error_text)
    end
  end

  describe "PATCH /:resource_name/:id with an error on the record" do
    let(:user) { create(:user) }

    before do
      patch iron_admin.resource_path("users", user),
            params: { record: { name: user.name, email: user.email, preferences: "{not valid json" } }, as: :html
    end

    it "shows it in the theme's error alert" do
      expect(classes_at("form [role=alert]")).to include(*theme.alert_palette[:error].split, theme.border_width)
    end

    context "with a theme that sets alert_shadow" do
      before do
        theme.alert_shadow = "shadow-md"
        patch iron_admin.resource_path("users", user),
              params: { record: { name: user.name, email: user.email, preferences: "{not valid json" } }, as: :html
      end

      it "gives the error alert that shadow" do
        expect(classes_at("form [role=alert]")).to include("shadow-md")
      end
    end
  end

  describe "GET /:resource_name/:id/edit with a tags field" do
    let(:post_record) { create(:post, category_tags: "ruby,rails") }
    let(:chips) { document.css("[data-tags-list] [data-tag]") }

    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      get iron_admin.edit_resource_path("posts", post_record), as: :html
    end

    it "renders each tag as a theme chip" do
      expect(chips.map { |chip| chip[:class].split }).to all(include(*theme.chip.split, *theme.badge_shape.split))
    end

    it "names each remove button after its tag" do
      expect(chips.map { |chip| chip.at_css("button")["aria-label"] }).to eq(["Remove ruby", "Remove rails"])
    end

    it "renders the chip its script copies for a new tag with the same classes" do
      expect(document.at_css("template[data-tag-template] [data-tag]")[:class]).to eq(chips.first[:class])
    end
  end

  describe "GET /:resource_name/new with radio and boolean group fields" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::WidgetResource)
      get iron_admin.new_resource_path("widgets"), as: :html
    end

    it "renders radio buttons as theme radio buttons" do
      expect(classes_at("input[type=radio]")).to eq(controls.radio(theme).split)
    end

    it "renders the group's checkboxes as theme checkboxes" do
      expect(classes_at("input[data-boolean-group-checkbox]")).to eq(controls.checkbox(theme).split)
    end
  end

  context "with a registered theme picked by the theme cookie" do
    before do
      IronAdmin.configuration.register_theme(:blocky) do |blocky|
        blocky.control_radius = "rounded-none"
        blocky.btn_primary = "bg-black text-white"
      end
      cookies["iron_admin_theme"] = "blocky"
      get iron_admin.new_resource_path("users"), as: :html
    end

    it "renders the inputs with that theme's radius" do
      expect(classes_at("#record_name")).to include("rounded-none")
    end

    it "renders the submit button with that theme's colors" do
      expect(classes_at("input[type=submit]")).to include("bg-black", "rounded-none")
    end
  end
end
