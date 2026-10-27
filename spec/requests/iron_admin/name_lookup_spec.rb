# frozen_string_literal: true

require "rails_helper"

# Names are read with `params.expect`: an unknown name is a 404, while a blank
# one ("/admin/%20") raises ParameterMissing, which ApplicationController
# answers with a bare 400.
RSpec.describe "Resource and tool names in the URL", type: :request do
  shared_examples "a lookup by name" do
    context "with a name that matches nothing" do
      let(:name) { "no_such_name" }

      it "responds with not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a blank name" do
      let(:name) { " " }

      it "responds with bad request" do
        expect(response).to have_http_status(:bad_request)
      end

      it "responds with an empty body" do
        expect(response.body).to be_empty
      end
    end
  end

  describe "GET /:resource_name" do
    before { get iron_admin.resources_path(name), as: :html }

    it_behaves_like "a lookup by name"
  end

  describe "GET /:resource_name/export" do
    before { get iron_admin.export_path(name, format: :csv) }

    it_behaves_like "a lookup by name"
  end

  describe "GET /:resource_name/import" do
    before { get iron_admin.resource_import_path(name), as: :html }

    it_behaves_like "a lookup by name"
  end

  describe "GET /tools/:tool_name" do
    before { get iron_admin.tool_path(name), as: :html }

    it_behaves_like "a lookup by name"
  end
end
