# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Theme switch", type: :request do
  let(:theme_cookie) do
    Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }
      .find { |cookie| cookie.start_with?("iron_admin_theme=") }
  end

  before { IronAdmin.configuration.register_theme(:midnight) }

  describe "POST /theme" do
    context "with a registered theme" do
      before { post iron_admin.theme_path, params: { theme: "midnight", return_to: "/admin/users?page=2" } }

      it "stores the theme in the cookie" do
        expect(cookies["iron_admin_theme"]).to eq("midnight")
      end

      it "keeps the cookie for a year" do
        expires = Time.httpdate(theme_cookie[/expires=([^;]+)/i, 1])

        expect(expires).to be_within(1.minute).of(1.year.from_now)
      end

      it "hides the cookie from JavaScript" do
        expect(theme_cookie).to match(/;\s*httponly/i)
      end

      it "sends the cookie on top-level navigation only" do
        expect(theme_cookie).to match(/;\s*samesite=lax/i)
      end

      it "does not require HTTPS for the cookie over HTTP" do
        expect(theme_cookie).not_to match(/;\s*secure/i)
      end

      it "redirects back to the page the switcher was on" do
        expect(response).to redirect_to("/admin/users?page=2")
      end

      it "redirects with 303 See Other" do
        expect(response).to have_http_status(:see_other)
      end
    end

    context "over HTTPS" do
      before do
        https!
        post iron_admin.theme_path, params: { theme: "midnight" }
      end

      it "sends the cookie only over HTTPS" do
        expect(theme_cookie).to match(/;\s*secure/i)
      end
    end

    context "with an unknown theme" do
      before do
        cookies["iron_admin_theme"] = "midnight"
        post iron_admin.theme_path, params: { theme: "unknown", return_to: "/admin/users" }
      end

      it "keeps the theme cookie" do
        expect(theme_cookie).to be_nil
      end

      it "explains the theme is not available" do
        expect(flash[:alert]).to eq(I18n.t("iron_admin.theme_switcher.unknown"))
      end

      it "redirects back with 303 See Other" do
        expect([response.location, response.status]).to eq(["http://www.example.com/admin/users", 303])
      end
    end

    context "with a theme name only the resolver knows" do
      before do
        IronAdmin.configuration.theme_resolver { |_request| :midnight }
        post iron_admin.theme_path, params: { theme: "custom" }
      end

      it "does not store it" do
        expect(theme_cookie).to be_nil
      end
    end

    context "with the theme param as an array" do
      before { post iron_admin.theme_path, params: { theme: ["midnight"] } }

      it "does not store it" do
        expect(theme_cookie).to be_nil
      end
    end

    describe "return_to" do
      {
        "an absolute URL" => "https://evil.example/phish",
        "a protocol-relative URL" => "//evil.example/phish",
        "a path with a backslash" => "/\\evil.example/phish",
        "a path with a tab" => "/\t/evil.example/phish",
        "a javascript: URL" => "javascript:alert(1)",
        "a relative path" => "users",
        "a path that cannot be parsed" => "/users/%zz",
      }.each do |description, return_to|
        context "with #{description}" do
          before { post iron_admin.theme_path, params: { theme: "midnight", return_to: return_to } }

          it "redirects to the admin root" do
            expect(response).to redirect_to(iron_admin.root_path)
          end
        end
      end

      context "when missing" do
        before { post iron_admin.theme_path, params: { theme: "midnight" } }

        it "redirects to the admin root" do
          expect(response).to redirect_to(iron_admin.root_path)
        end
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

      it "rejects a request without the CSRF token" do
        expect { post iron_admin.theme_path, params: { theme: "midnight" } }
          .to raise_error(ActionController::InvalidAuthenticityToken)
      end

      it "accepts a request with the CSRF token" do
        get iron_admin.resources_path("users")
        token = response.parsed_body.at_css("meta[name='csrf-token']")[:content]
        post iron_admin.theme_path, params: { theme: "midnight", authenticity_token: token }

        expect(cookies["iron_admin_theme"]).to eq("midnight")
      end
    end

    context "when authentication fails" do
      before do
        IronAdmin.configuration.authenticate { |controller| controller.redirect_to "/login" }
        post iron_admin.theme_path, params: { theme: "midnight" }
      end

      it "redirects like every other admin page" do
        expect(response).to redirect_to("/login")
      end

      it "does not store the theme" do
        expect(theme_cookie).to be_nil
      end
    end
  end

  describe "the route" do
    it "comes before the resource routes, which would read it as a create of a theme resource" do
      expect(IronAdmin::Engine.routes.recognize_path("/theme", method: :post))
        .to include(controller: "iron_admin/themes", action: "update")
    end
  end
end
