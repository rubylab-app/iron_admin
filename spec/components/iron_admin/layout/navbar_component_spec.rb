require "rails_helper"

RSpec.describe IronAdmin::Layout::NavbarComponent, type: :component do
  describe "#initialize" do
    it "accepts current_user parameter" do
      user = instance_double(User, name: "Test User")
      component = described_class.new(current_user: user)

      expect(component.instance_variable_get(:@current_user)).to eq(user)
    end

    it "defaults current_user to nil" do
      component = described_class.new

      expect(component.instance_variable_get(:@current_user)).to be_nil
    end
  end

  describe "global search box" do
    subject(:search_input) do
      with_controller_class(controller_class) do
        with_request_url("/admin/#{path}?q=Rails") { render_inline(described_class.new) }
      end.at_css("header input[name='q']")
    end

    context "when on the search results page" do
      let(:controller_class) { IronAdmin::SearchController }
      let(:path) { "search" }

      it "keeps the submitted query" do
        expect(search_input[:value]).to eq("Rails")
      end

      it "has an accessible name" do
        expect(search_input["aria-label"]).to eq("Search across all resources")
      end
    end

    # On an index page, q is that resource's own search box.
    context "when on another page" do
      let(:controller_class) { IronAdmin::ResourcesController }
      let(:path) { "users" }

      it "stays empty" do
        expect(search_input[:value]).to be_blank
      end

      it "has an accessible name" do
        expect(search_input["aria-label"]).to eq("Search across all resources")
      end
    end
  end

  describe "component class" do
    it "inherits from ViewComponent::Base" do
      expect(described_class.superclass).to eq(ViewComponent::Base)
    end
  end
end
