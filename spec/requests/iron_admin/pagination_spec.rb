# frozen_string_literal: true

require "rails_helper"
require_relative "../../support/test_resources"

RSpec.describe "IronAdmin pagination", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin.configuration.per_page = 2
    create_list(:user, 5)
  end

  describe "GET /:resource_name" do
    context "with a page in range" do
      subject(:pagination) { response.parsed_body.at_css("nav[aria-label='Pagination']") }

      before { get iron_admin.resources_path("users"), params: { page: 2 }, as: :html }

      it "shows the record range" do
        expect(pagination.text.squish).to include("Showing 3 to 4 of 5 results")
      end

      it "links to the next page" do
        expect(pagination.at_css("a[href$='page=3']")).not_to be_nil
      end
    end

    # These raised (HTTP 500) on pagy releases below the gemspec floor:
    # 0/-1/abc until 43.2.4, Array/Hash until 43.2.9 (#872), huge pages until 43.7.1 (#929).
    {
      "zero" => "0",
      "negative" => "-1",
      "non-numeric" => "abc",
      "an array (page[]=1)" => ["1"],
      "a hash (page[a]=1)" => { "a" => "1" },
      "2**63, past the database OFFSET range" => (2**63).to_s,
      "10**30, far past the database OFFSET range" => (10**30).to_s,
    }.each do |description, value|
      context "when the page param is #{description}" do
        it "responds with success" do
          get iron_admin.resources_path("users"), params: { page: value }, as: :html
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
