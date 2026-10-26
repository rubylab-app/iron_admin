require "rails_helper"

RSpec.describe "IronAdmin::Dashboard", type: :request do
  describe "GET /" do
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
  end
end
