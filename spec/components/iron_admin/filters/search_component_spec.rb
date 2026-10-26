require "rails_helper"
require_relative "../../../../app/components/iron_admin/filters/search_component"

RSpec.describe IronAdmin::Filters::SearchComponent, type: :component do
  describe "#initialize" do
    it "has default placeholder" do
      component = described_class.new(form_url: "/search")
      expect(component.placeholder).to eq("Search...")
    end

    it "accepts custom placeholder" do
      component = described_class.new(form_url: "/search", placeholder: "Find users...")
      expect(component.placeholder).to eq("Find users...")
    end

    it "accepts value" do
      component = described_class.new(form_url: "/search", value: "test query")
      expect(component.value).to eq("test query")
    end

    it "accepts hidden_params" do
      component = described_class.new(form_url: "/search", hidden_params: { scope: "active" })
      expect(component.hidden_params).to eq({ scope: "active" })
    end
  end

  describe "#input_classes" do
    it "includes border class" do
      component = described_class.new(form_url: "/search")
      expect(component.input_classes).to include("border")
    end

    it "includes left padding for icon" do
      component = described_class.new(form_url: "/search")
      expect(component.input_classes).to include("pl-10")
    end
  end

  describe "accessible names" do
    let(:hidden_params) { { "filters[title][op]" => "contains" } }

    it "names the search input after the resource" do
      component = described_class.new(form_url: "/search", resource_class: IronAdmin::Resources::UserResource)
      expect(render_inline(component).at_css("input[name=q]")["aria-label"]).to eq("Search Users")
    end

    it "falls back to the placeholder without a resource" do
      component = described_class.new(form_url: "/search", placeholder: "Find users...")
      expect(render_inline(component).at_css("input[name=q]")["aria-label"]).to eq("Find users...")
    end

    it "renders the hidden params without ids, which a filter control may use" do
      component = described_class.new(form_url: "/search", hidden_params: hidden_params)
      expect(render_inline(component).at_css("input[type=hidden]")["id"]).to be_nil
    end
  end
end
