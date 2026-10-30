# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Theme of each request", type: :request do
  let(:new_button_classes) do
    response.parsed_body.at_css("a[href='#{iron_admin.new_resource_path("users")}']")[:class].split
  end

  before do
    IronAdmin.configuration.register_theme(:midnight) { |t| t.btn_primary = "midnight-primary" }
  end

  context "with the cookie of a registered theme" do
    before do
      cookies["iron_admin_theme"] = "midnight"
      get iron_admin.resources_path("users"), as: :html
    end

    it "renders the page with that theme" do
      expect(new_button_classes).to include("midnight-primary")
    end
  end

  context "without a theme cookie" do
    before { get iron_admin.resources_path("users"), as: :html }

    it "renders the page with the default theme" do
      expect(new_button_classes).to include("bg-zinc-900")
    end
  end

  context "with the cookie of an unknown theme" do
    before do
      cookies["iron_admin_theme"] = "unknown"
      get iron_admin.resources_path("users"), as: :html
    end

    it "renders the page with the default theme" do
      expect(new_button_classes).to include("bg-zinc-900")
    end
  end

  context "when a request without the cookie follows one with it" do
    before do
      cookies["iron_admin_theme"] = "midnight"
      get iron_admin.resources_path("users"), as: :html
      cookies.delete("iron_admin_theme")
      get iron_admin.resources_path("users"), as: :html
    end

    it "renders the second page with the default theme" do
      expect(new_button_classes).not_to include("midnight-primary")
    end
  end

  context "when authentication renders the response" do
    before do
      IronAdmin.configuration.authenticate do |controller|
        controller.render plain: "theme=#{IronAdmin.current_theme.name}", status: :unauthorized
      end
      cookies["iron_admin_theme"] = "midnight"
      get iron_admin.resources_path("users"), as: :html
    end

    it "has already resolved the theme" do
      expect(response.body).to eq("theme=midnight")
    end
  end

  context "with a theme cookie that is not valid UTF-8" do
    before do
      allow(Rails.logger).to receive(:warn)
      get iron_admin.resources_path("users"), headers: { "Cookie" => "iron_admin_theme=%FF" }, as: :html
    end

    it "renders the page with the default theme" do
      expect(new_button_classes).to include("bg-zinc-900")
    end

    it "logs no warning" do
      expect(Rails.logger).not_to have_received(:warn).with(/theme_resolver raised/)
    end
  end

  context "with a resolver that raises" do
    before do
      IronAdmin.configuration.theme_resolver { |_request| raise "session store down" }
      get iron_admin.resources_path("users"), as: :html
    end

    it "renders the page with the default theme" do
      expect(new_button_classes).to include("bg-zinc-900")
    end
  end
end
