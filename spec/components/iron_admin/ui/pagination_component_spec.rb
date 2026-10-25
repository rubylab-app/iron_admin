require "rails_helper"

RSpec.describe IronAdmin::Ui::PaginationComponent, type: :component do
  subject(:component) { described_class.new(pagy: pagy) }

  let(:paginator) do
    Class.new do
      include Pagy::Method

      public :pagy
    end
  end
  let(:request_hash) { { base_url: "http://test.host", path: "/admin/users", params: { "q" => "smith" } } }
  let(:current_page) { 2 }
  let(:pagy) { paginator.new.pagy((1..50).to_a, page: current_page, limit: 10, request: request_hash).first }

  describe "#render?" do
    context "with a single page" do
      let(:pagy) { paginator.new.pagy((1..5).to_a, limit: 10, request: request_hash).first }

      it "returns false" do
        expect(component.render?).to be(false)
      end
    end

    context "with several pages" do
      it "returns true" do
        expect(component.render?).to be(true)
      end
    end
  end

  describe "#series" do
    it "returns page numbers with the current page as a String" do
      expect(component.series).to eq([1, "2", 3, 4, 5])
    end
  end

  describe "#page_url" do
    it "preserves the current query params" do
      expect(component.page_url(3)).to eq("/admin/users?q=smith&page=3")
    end
  end

  describe "rendering" do
    subject(:html) { render_inline(component) }

    it "shows the record range" do
      expect(html.text.squish).to include("Showing 11 to 20 of 50 results")
    end

    it "links to the previous page" do
      expect(html.at_css("a[aria-label='Previous']")[:href]).to eq("/admin/users?q=smith&page=1")
    end

    it "links to the next page" do
      expect(html.at_css("a[aria-label='Next']")[:href]).to eq("/admin/users?q=smith&page=3")
    end

    it "marks the current page" do
      expect(html.at_css("span[aria-current='page']").text).to eq("2")
    end

    context "with many pages" do
      let(:current_page) { 1 }
      let(:pagy) { paginator.new.pagy((1..500).to_a, page: current_page, limit: 10, request: request_hash).first }

      it "renders a gap" do
        expect(html.css("span.cursor-default").map(&:text)).to include("...")
      end
    end

    context "when on the last page" do
      let(:current_page) { 5 }

      it "disables the next link" do
        expect(html.css("a[aria-label='Next']")).to be_empty
      end
    end
  end
end
