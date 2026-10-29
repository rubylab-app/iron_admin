require "rails_helper"

RSpec.describe IronAdmin::ApplicationController, type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  describe "authentication" do
    context "when authenticate block is configured" do
      it "executes the authenticate block" do
        executed = false
        IronAdmin.configure do |config|
          config.authenticate { |_controller| executed = true }
        end

        get iron_admin.resources_path("users"), as: :html
        expect(executed).to be true
      end
    end

    context "when the authenticate block returns false" do
      before do
        IronAdmin.configure do |config|
          config.authenticate { |_controller| false }
        end
      end

      context "with an HTML request" do
        before { get iron_admin.resources_path("users"), as: :html }

        it "denies access" do
          expect(response).to have_http_status(:forbidden)
        end

        it "renders the admin error page" do
          heading = response.parsed_body.at_css("#cp-error-page h1")&.text&.squish

          expect(heading).to eq("Not authorized")
        end
      end

      # The dummy app replaces the engine layout with a bare one, so use the
      # engine's own views. Otherwise a denial looks fine while the real shell
      # still renders, and a :read condition that calls user.admin? 500s.
      context "with an HTML request rendered by the engine layout" do
        around do |example|
          original_view_paths = described_class.view_paths
          described_class.prepend_view_path(IronAdmin::Engine.root.join("app/views"))
          example.run
        ensure
          described_class.view_paths = original_view_paths
        end

        before do
          guarded = Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.name = "AuthShellGuardedResource"
            def self.resource_name = "auth_shell_users"

            policy { allow :read, if: ->(user) { user.admin? } }
          end
          IronAdmin::ResourceRegistry.register(guarded)

          get iron_admin.resources_path("users"), as: :html
        end

        it "denies access instead of failing the policy condition" do
          expect(response).to have_http_status(:forbidden)
        end

        it "renders the error page" do
          heading = response.parsed_body.at_css("#cp-error-page h1")&.text&.squish

          expect(heading).to eq("Not authorized")
        end

        it "does not render the sidebar" do
          expect(response.parsed_body.at_css("#cp-sidebar-panel")).not_to be_present
        end

        it "does not link into the admin" do
          expect(response.parsed_body.css("a")).to be_empty
        end

        it "does not render the navbar" do
          expect(response.parsed_body.at_css("header")).not_to be_present
        end

        it "keeps the theme color scheme" do
          expect(response.parsed_body.at_css("html")[:class].split).to include("scheme-light")
        end

        it "uses the theme's page background" do
          expect(response.parsed_body.at_css("body")[:class].split).to include("bg-zinc-50")
        end

        it "links a stylesheet" do
          hrefs = response.parsed_body.css("head link[rel='stylesheet']").pluck(:href)

          expect(hrefs).to include(a_string_including("tailwind"))
        end
      end

      context "with a CSV export" do
        before { get iron_admin.export_path("users", format: :csv) }

        it "denies access" do
          expect(response).to have_http_status(:forbidden)
        end

        it "returns an empty body" do
          expect(response.body).to be_empty
        end
      end

      context "with a JSON export" do
        before { get iron_admin.export_path("users", format: :json) }

        it "denies access" do
          expect(response).to have_http_status(:forbidden)
        end

        it "returns an empty body" do
          expect(response.body).to be_empty
        end
      end

      # A host template that declares only the error local must still render.
      # Passing any other local raises "unknown local" and turns the 403 into a 500.
      context "when the host error template declares only the error local" do
        around do |example|
          directory = Dir.mktmpdir
          template = File.join(directory, "iron_admin/shared/error.html.erb")
          FileUtils.mkdir_p(File.dirname(template))
          File.write(template, <<~ERB)
            <%# locals: (error:) -%>
            <p id="strict-error"><%= error %></p>
          ERB
          original_view_paths = described_class.view_paths
          described_class.prepend_view_path(directory)
          example.run
        ensure
          described_class.view_paths = original_view_paths
          FileUtils.remove_entry(directory) if directory
        end

        before { get iron_admin.resources_path("users"), as: :html }

        it "denies access" do
          expect(response).to have_http_status(:forbidden)
        end

        it "renders the overriding template" do
          expect(response.body).to include('id="strict-error"')
        end
      end
    end

    context "when the authenticate block returns nil" do
      it "allows access" do
        IronAdmin.configure do |config|
          config.authenticate { |_controller| nil }
        end

        get iron_admin.resources_path("users"), as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the authenticate block returns true" do
      it "allows access" do
        IronAdmin.configure do |config|
          config.authenticate { |_controller| true }
        end

        get iron_admin.resources_path("users"), as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the authenticate block's value is some other object" do
      it "allows access" do
        marker = "signed-in"
        IronAdmin.configure do |config|
          config.authenticate { |_controller| marker }
        end

        get iron_admin.resources_path("users"), as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the authenticate block redirects" do
      before do
        IronAdmin.configure do |config|
          config.authenticate { |controller| controller.redirect_to "/login" }
        end

        get iron_admin.resources_path("users"), as: :html
      end

      it "responds with 302" do
        expect(response).to have_http_status(:found)
      end

      it "sends the browser to the redirect target" do
        expect(response).to redirect_to("/login")
      end
    end

    context "when the authenticate block renders and then returns false" do
      before do
        IronAdmin.configure do |config|
          config.authenticate do |controller|
            controller.head :forbidden
            false
          end
        end
      end

      it "does not render twice" do
        expect { get iron_admin.resources_path("users"), as: :html }.not_to raise_error
      end

      it "keeps the forbidden status" do
        get iron_admin.resources_path("users"), as: :html

        expect(response).to have_http_status(:forbidden)
      end

      it "keeps the response the block rendered" do
        get iron_admin.resources_path("users"), as: :html

        expect(response.body).to be_empty
      end
    end

    context "when the authenticate block returns whether the user is an admin" do
      it "denies a non-admin" do
        user = create(:user, role: "member")
        IronAdmin.configure do |config|
          config.authenticate { |_controller| user.role == "admin" }
        end

        get iron_admin.resources_path("users"), as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when authenticate block is not configured" do
      it "allows access" do
        get iron_admin.resources_path("users"), as: :html
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "current_user helper" do
    context "when current_user block is configured" do
      it "executes the current_user block" do
        test_user = create(:user, name: "Admin")
        IronAdmin.configure do |config|
          config.current_user { |_controller| test_user }
        end

        get iron_admin.resources_path("users"), as: :html
        expect(response).to have_http_status(:ok)
      end

      it "provides current user to views" do
        test_user = create(:user, name: "Admin")
        IronAdmin.configure do |config|
          config.current_user { |_controller| test_user }
        end

        get iron_admin.root_path, as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "when current_user block is not configured" do
      it "returns nil for current_user" do
        get iron_admin.resources_path("users"), as: :html
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
