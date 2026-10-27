require "rails_helper"
require_relative "../../../../app/components/iron_admin/filters/bar_component"

RSpec.describe IronAdmin::Filters::BarComponent, type: :component do
  describe "#initialize" do
    it "stores form_url" do
      component = described_class.new(form_url: "/admin/users")
      expect(component.form_url).to eq("/admin/users")
    end

    it "defaults scope to nil" do
      component = described_class.new(form_url: "/admin/users")
      expect(component.scope).to be_nil
    end

    it "defaults query to nil" do
      component = described_class.new(form_url: "/admin/users")
      expect(component.query).to be_nil
    end

    it "defaults active_count to 0" do
      component = described_class.new(form_url: "/admin/users")
      expect(component.active_count).to eq(0)
    end

    it "accepts all options" do
      component = described_class.new(
        form_url: "/admin/users",
        scope: "active",
        query: "test",
        active_count: 3
      )
      expect(component.scope).to eq("active")
      expect(component.query).to eq("test")
      expect(component.active_count).to eq(3)
    end
  end

  describe "#has_active_filters?" do
    it "returns false when active_count is 0" do
      component = described_class.new(form_url: "/admin/users", active_count: 0)
      expect(component.has_active_filters?).to be false
    end

    it "returns true when active_count is positive" do
      component = described_class.new(form_url: "/admin/users", active_count: 2)
      expect(component.has_active_filters?).to be true
    end
  end

  describe "#trigger_classes" do
    it "includes flex layout" do
      component = described_class.new(form_url: "/admin/users")
      expect(component.trigger_classes).to include("inline-flex")
    end

    it "includes cursor pointer" do
      component = described_class.new(form_url: "/admin/users")
      expect(component.trigger_classes).to include("cursor-pointer")
    end

    it "includes border and shadow" do
      component = described_class.new(form_url: "/admin/users")
      expect(component.trigger_classes).to include("border")
      expect(component.trigger_classes).to include("shadow-sm")
    end
  end

  describe "#dropdown_classes" do
    it "includes absolute positioning" do
      component = described_class.new(form_url: "/admin/users")
      expect(component.dropdown_classes).to include("absolute")
    end

    it "includes z-index" do
      component = described_class.new(form_url: "/admin/users")
      expect(component.dropdown_classes).to include("z-20")
    end

    it "includes width" do
      component = described_class.new(form_url: "/admin/users")
      expect(component.dropdown_classes).to include("w-72")
    end
  end

  describe "slots" do
    it "has filters slot" do
      expect(described_class.registered_slots).to have_key(:filters)
    end
  end

  describe "hidden fields" do
    subject(:hidden_ids) { render_inline(component).css("input[type=hidden]").pluck("id").compact }

    let(:component) { described_class.new(form_url: "/admin/users", scope: "active", query: "ada") }

    it "renders scope and q without ids, so they do not clash with the search input's id" do
      expect(hidden_ids).to be_empty
    end
  end

  describe "sort" do
    subject(:rendered) { render_inline(component) }

    let(:hidden_fields) do
      rendered.css("input[type=hidden]").to_h { |input| [input[:name], input[:value]] }
    end

    context "with the current sort and direction" do
      let(:component) do
        described_class.new(form_url: "/admin/users", scope: "active", query: "ada",
                            current_sort: "name", current_direction: "desc")
      end

      it "keeps them as hidden fields when the filters are applied" do
        expect(hidden_fields).to include("sort" => "name", "direction" => "desc")
      end

      it "keeps the scope, search and sort when the filters are cleared" do
        clear_link = rendered.css("a").find { |link| link.text.squish == "Clear" }

        expect(Rack::Utils.parse_nested_query(URI.parse(clear_link[:href]).query)).to eq(
          "scope" => "active", "q" => "ada", "sort" => "name", "direction" => "desc"
        )
      end
    end

    context "without a sort" do
      let(:component) { described_class.new(form_url: "/admin/users") }

      it "adds no sort fields" do
        expect(hidden_fields.keys).not_to include("sort", "direction")
      end

      it "clears the filters to the form URL" do
        expect(rendered.css("a").find { |link| link.text.squish == "Clear" }[:href]).to eq("/admin/users")
      end
    end
  end
end
