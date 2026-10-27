require "rails_helper"

RSpec.describe "IronAdmin::Dashboard", type: :request do
  describe "GET /" do
    describe "page title" do
      subject(:title_classes) do
        get iron_admin.root_path, headers: { "Accept" => "text/html" }
        response.parsed_body.at_css("h1")[:class].split
      end

      it "uses the theme's page_title" do
        expect(title_classes).to include("text-xl", "font-semibold", "tracking-tight", "text-zinc-900")
      end

      context "with a registered theme picked by the theme cookie" do
        before do
          IronAdmin.configuration.register_theme(:editorial) do |t|
            t.page_title = "text-3xl font-normal text-stone-900"
            t.heading_font = "font-[family-name:Fraunces,serif]"
          end
          cookies["iron_admin_theme"] = "editorial"
        end

        it "uses that theme's page_title and heading_font" do
          expect(title_classes).to include("text-3xl", "font-normal", "font-[family-name:Fraunces,serif]")
        end

        it "drops the default theme's page_title" do
          expect(title_classes).not_to include("text-xl", "font-semibold")
        end
      end
    end

    context "without dashboard class configured" do
      it "returns success" do
        get iron_admin.root_path, headers: { "Accept" => "text/html" }

        expect(response).to have_http_status(:ok)
      end

      it "renders dashboard index template" do
        get iron_admin.root_path, headers: { "Accept" => "text/html" }

        expect(response.body).to be_present
      end

      context "with the page container" do
        subject(:container_classes) do
          get iron_admin.root_path, headers: { "Accept" => "text/html" }
          response.parsed_body.at_css("h1").parent[:class].split
        end

        it "pads the page like the other admin pages" do
          expect(container_classes).to include("p-4", "sm:p-6", "lg:p-8")
        end

        it "does not use the fixed desktop padding on small screens" do
          expect(container_classes).not_to include("p-8")
        end
      end
    end

    context "with dashboard class configured" do
      let(:dashboard_class) { Class.new(IronAdmin::Dashboard) }

      before do
        IronAdmin.dashboard_class = dashboard_class
      end

      it "returns success" do
        get iron_admin.root_path, headers: { "Accept" => "text/html" }

        expect(response).to have_http_status(:ok)
      end

      it "renders dashboard content" do
        get iron_admin.root_path, headers: { "Accept" => "text/html" }

        expect(response.body).to be_present
      end
    end

    context "with metrics" do
      subject(:grid_classes) do
        get iron_admin.root_path, headers: { "Accept" => "text/html" }
        response.parsed_body.at_css("#metric_total_users").parent[:class].split
      end

      before do
        IronAdmin.dashboard_class = Class.new(IronAdmin::Dashboard) do
          metric(:total_users, icon: "users", live: true) { 42 }
        end
      end

      it "keeps two columns at the lg breakpoint, where the sidebar leaves too little room for four" do
        expect(grid_classes).not_to include("lg:grid-cols-4")
      end

      it "switches to four columns at the xl breakpoint" do
        expect(grid_classes).to include("xl:grid-cols-4")
      end
    end

    context "with recent records" do
      subject(:table) do
        get iron_admin.root_path, headers: { "Accept" => "text/html" }
        response.parsed_body.at_css("table")
      end

      before do
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
        create(:post, title: "Older post", created_at: 2.days.ago)
        create(:post, title: "Newest post", created_at: 1.hour.ago)
        create(:post, title: "Oldest post", created_at: 1.week.ago)
        IronAdmin.dashboard_class = Class.new(IronAdmin::Dashboard) { recent :posts, limit: 2 }
      end

      it "lists the newest records first" do
        expect(table.css("tbody tr").map { |row| row.css("td")[1].text.strip }).to eq(["Newest post", "Older post"])
      end

      it "shows the label column instead of the first database columns" do
        expect(table.css("th").map { |header| header.text.strip }).to eq(["Id", "Title", "Published", "Created at"])
      end
    end

    context "with recent records that have a field hidden from the current user" do
      subject(:column_headers) do
        get iron_admin.root_path, headers: { "Accept" => "text/html" }
        response.parsed_body.css("table th").map { |header| header.text.strip }
      end

      before do
        IronAdmin.configure { |config| config.current_user { "viewer" } }
        IronAdmin::ResourceRegistry.register(Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.resource_name = "staff_members"

          field :email, visible: ->(user) { user != "viewer" }
        end)
        IronAdmin.dashboard_class = Class.new(IronAdmin::Dashboard) { recent :staff_members }
      end

      it "leaves the field out" do
        expect(column_headers).not_to include("Email")
      end
    end

    context "with recent records of a resource the current user cannot read" do
      subject(:body) do
        get iron_admin.root_path, headers: { "Accept" => "text/html" }
        response.body
      end

      let(:members_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.resource_name = "dashboard_members"

          policy { deny :read }
        end
      end

      before do
        IronAdmin.configure { |config| config.current_user { "viewer" } }
        IronAdmin::ResourceRegistry.register(members_resource)
        create(:user, name: "Secret Dash User", email: "secret-dash@example.com")
        IronAdmin.dashboard_class = Class.new(IronAdmin::Dashboard) { recent :dashboard_members }
      end

      it "does not list them" do
        expect(body).not_to include("secret-dash@example.com")
      end

      context "when the policy lets only other users read" do
        let(:members_resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.resource_name = "dashboard_members"

            policy { allow :read, if: ->(user) { user == "admin" } }
          end
        end

        it "does not list them" do
          expect(body).not_to include("secret-dash@example.com")
        end
      end

      context "when deny_actions disables reading" do
        let(:members_resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.resource_name = "dashboard_members"

            deny_actions :read
          end
        end

        it "does not list them" do
          expect(body).not_to include("secret-dash@example.com")
        end
      end
    end

    context "with recent records and a tenant scope" do
      subject(:body) do
        get iron_admin.root_path, headers: { "Accept" => "text/html" }
        response.body
      end

      let(:recent_scope) { nil }

      before do
        IronAdmin.configure { |config| config.tenant_scope { |scope| scope.where(active: true) } }
        create(:user, name: "Tenant User", email: "tenant@example.com", active: true)
        create(:user, name: "Other Tenant User", email: "other-tenant@example.com", active: false)
        scope = recent_scope
        IronAdmin.dashboard_class = Class.new(IronAdmin::Dashboard) { recent :users, scope: scope }
      end

      it "lists the records of the tenant" do
        expect(body).to include("tenant@example.com")
      end

      it "leaves out the records of other tenants" do
        expect(body).not_to include("other-tenant@example.com")
      end

      context "when the recent table has its own scope" do
        let(:recent_scope) { -> { order(id: :desc) } }

        it "still leaves out the records of other tenants" do
          expect(body).not_to include("other-tenant@example.com")
        end
      end
    end
  end
end
