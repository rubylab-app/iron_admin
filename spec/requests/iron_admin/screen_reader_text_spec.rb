# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Screen reader text in tables", type: :request do
  let(:document) do
    get path, headers: { "Accept" => "text/html" }
    response.parsed_body
  end

  before { create(:user, name: "Ada", active: true) }

  shared_examples "screen reader text kept inside its cell" do
    it "renders screen reader text in the table" do
      expect(sr_only_in_table_cells(document)).to be_present
    end

    it "gives each one a positioned ancestor inside its cell" do
      expect(unpositioned_sr_only_in_table_cells(document)).to be_empty
    end
  end

  describe "the index page" do
    let(:path) { iron_admin.resources_path("users") }

    it_behaves_like "screen reader text kept inside its cell"
  end

  describe "a dashboard recent table" do
    let(:path) { iron_admin.root_path }

    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      create(:post, title: "Launch", published: true)
      IronAdmin.dashboard_class = Class.new(IronAdmin::Dashboard) { recent :posts, limit: 5 }
    end

    it_behaves_like "screen reader text kept inside its cell"
  end
end
