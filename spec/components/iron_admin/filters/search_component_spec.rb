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
    subject(:input_classes) { described_class.new(form_url: "/search").input_classes.split }

    it "uses the theme's border width" do
      expect(input_classes).to include("border")
    end

    it "includes left padding for icon" do
      expect(input_classes).to include("pl-9")
    end

    it "is a 36px filter input" do
      expect(input_classes).to include("h-9", "bg-white", "rounded-md")
    end

    context "with a registered theme active" do
      before do
        IronAdmin::RequestContext.theme = IronAdmin.configuration.register_theme(:midnight) { |t| t.card_bg = "bg-zinc-900" }
      end

      it "uses that theme's surface" do
        expect(input_classes).to include("bg-zinc-900")
      end
    end
  end

  describe "search icon" do
    subject(:icon) { render_inline(described_class.new(form_url: "/search")).at_css("svg") }

    it "uses the theme's decorative icon color" do
      expect(icon[:class].split).to include("text-zinc-400")
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
