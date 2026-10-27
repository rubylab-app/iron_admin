# frozen_string_literal: true

require "rails_helper"
require "ostruct"
require_relative "../../support/test_resources"

# The index, show, search and audit pages take their colors, borders, radii,
# shadows and label case from the theme of the request.
RSpec.describe "Theme of the data pages", type: :request do
  let(:document) { response.parsed_body }
  let(:styles) { IronAdmin::Resources::Styles }
  let(:neutral) { IronAdmin.configuration.theme }
  let(:midnight) { IronAdmin.configuration.find_theme(:midnight) }
  let(:user) { create(:user, name: "Ada Lovelace") }

  def classes_of(node)
    node[:class].split
  end

  before do
    register_test_resources
    IronAdmin.configuration.register_theme(:midnight) do |t|
      t.page_title = "text-2xl font-black text-white"
      t.card_bg = "bg-zinc-900"
      t.label_transform = "uppercase tracking-wider"
      t.table_frame = "ring-1 ring-zinc-700"
      t.table_sticky_shadow = "shadow-none"
      t.popover_shadow = "shadow-2xl"
      t.item_hover = "hover:bg-zinc-800"
      t.badge_palette[:green] = "bg-emerald-950 text-emerald-300"
    end
  end

  shared_context "with the midnight theme" do
    before { cookies["iron_admin_theme"] = "midnight" }
  end

  describe "GET /:resource_name" do
    let(:header_cell) { document.css("thead th").find { |cell| cell.at_css("a") } }
    let(:sticky_header_cell) { document.css("thead th").last }

    before { create(:license, user: user, license_key: "KEY-1") }

    context "with the default theme" do
      before { get iron_admin.resources_path("licenses"), as: :html }

      it "titles the page with the theme's page title" do
        expect(classes_of(document.at_css("h1"))).to eq(styles.page_title(neutral).split)
      end

      it "scrolls the table inside the table frame" do
        expect(document.at_css("table").parent[:class]).to eq(styles.table_frame(neutral))
      end

      it "styles the sortable header cells with the header cell classes" do
        expect(header_cell[:class]).to eq(styles.header_cell(neutral))
      end

      it "casts the theme's sticky column shadow from the actions column" do
        expect(classes_of(sticky_header_cell)).to include(*styles.sticky_header_cell(neutral).split)
      end

      it "renders the status as a badge in the theme's palette" do
        expect(classes_of(document.css("tbody td span").find { |span| span.text.strip == "Active" })).to include("bg-emerald-50")
      end

      it "floats the filter panel with the theme's popover shadow" do
        expect(classes_of(document.at_css("details summary + div"))).to include("shadow-lg")
      end

      it "draws the select chevron from engine.css, with no color in the markup" do
        expect(document.css("details select").map { |select| [select[:style], classes_of(select).include?("cp-select-chevron")] }.uniq).to eq([[nil, true]])
      end

      it "takes every bulk selection checkbox from the theme's checkbox classes" do
        expect(document.css("table input[type=checkbox]").map { |box| classes_of(box) }.uniq.size).to eq(1)
      end
    end

    context "with a registered theme active" do
      include_context "with the midnight theme"

      before { get iron_admin.resources_path("licenses"), as: :html }

      it "titles the page with that theme's page title" do
        expect(classes_of(document.at_css("h1"))).to include("text-2xl", "font-black", "text-white")
      end

      it "adds that theme's table frame" do
        expect(classes_of(document.at_css("table").parent)).to include("ring-1", "ring-zinc-700")
      end

      it "writes the header cells with that theme's label transform" do
        expect(classes_of(header_cell)).to include("uppercase", "tracking-wider")
      end

      it "uses that theme's sticky column shadow" do
        expect(classes_of(sticky_header_cell)).to include("shadow-none")
      end

      it "uses that theme's badge palette" do
        expect(classes_of(document.css("tbody td span").find { |span| span.text.strip == "Active" })).to include("bg-emerald-950")
      end

      it "floats the filter panel with that theme's popover shadow" do
        expect(classes_of(document.at_css("details summary + div"))).to include("shadow-2xl")
      end
    end
  end

  describe "GET /:resource_name with a numeric column" do
    let(:numeric_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name = "NumericColumnLicenseResource"
        def self.resource_name = "numeric_column_licenses"

        index_fields :license_key, :max_devices
      end
    end

    let(:cells) { document.at_css("tbody tr").css("td") }

    before do
      IronAdmin::ResourceRegistry.register(numeric_resource)
      create(:license, user: user, max_devices: 3)
      get iron_admin.resources_path("numeric_column_licenses"), as: :html
    end

    it "lines up the digits of the numeric cell" do
      expect(classes_of(cells[1])).to include("tabular-nums")
    end

    it "keeps proportional digits in the text cell" do
      expect(classes_of(cells[0])).not_to include("tabular-nums")
    end
  end

  describe "GET /:resource_name/:id" do
    let(:fields_panel) { document.at_css("dl").parent }

    context "with the default theme" do
      before { get iron_admin.resource_path("users", user), as: :html }

      it "titles the page with the theme's page title" do
        expect(classes_of(document.at_css("h1"))).to include(*styles.page_title(neutral).split)
      end

      it "renders the fields in a panel" do
        expect(classes_of(fields_panel)).to include(*styles.panel(neutral).split)
      end

      it "lays out each field as a detail row" do
        expect(document.at_css("dl > div")[:class]).to eq(styles::DETAIL_ROW)
      end
    end

    context "with a registered theme active" do
      include_context "with the midnight theme"

      before { get iron_admin.resource_path("users", user), as: :html }

      it "renders the fields on that theme's card background" do
        expect(classes_of(fields_panel)).to include("bg-zinc-900")
      end
    end
  end

  describe "GET /:resource_name/:id with member actions" do
    let(:license) { create(:license, user: user) }

    before { get iron_admin.resource_path("licenses", license), as: :html }

    it "renders each action as a secondary button" do
      path = iron_admin.resource_action_path("licenses", license, :revoke)
      expect(document.at_css("form[action='#{path}'] button")[:class]).to eq(styles.secondary_button(neutral))
    end
  end

  describe "GET /search" do
    let(:result) { document.at_css("a[href='#{iron_admin.resource_path("users", user)}']") }

    before { user }

    context "with the default theme" do
      before { get iron_admin.search_path(q: "Ada") }

      it "titles the page with the theme's page title" do
        expect(classes_of(document.at_css("h1"))).to include(*styles.page_title(neutral).split)
      end

      it "lists the results in a panel whose rows are divided" do
        expect(classes_of(result.parent)).to include(*styles.panel(neutral).split, *styles.divided(neutral).split)
      end

      it "highlights a result on hover with the theme's item hover" do
        expect(classes_of(result)).to include("hover:bg-zinc-100")
      end
    end

    context "with a registered theme active" do
      include_context "with the midnight theme"

      before { get iron_admin.search_path(q: "Ada") }

      it "uses that theme's item hover" do
        expect(classes_of(result)).to include("hover:bg-zinc-800")
      end
    end
  end

  describe "GET /audit" do
    let(:action_badge) { document.css("tbody td span").find { |span| span.text.strip == "Create" } }

    def log_a_change
      IronAdmin.configure { |c| c.audit_enabled = true }
      IronAdmin::AuditLog.log(OpenStruct.new(user: nil, action: :create, resource: "UserResource", record_id: 1,
                                             changes: { "name" => [nil, "Ada"] }, ip_address: "127.0.0.1"))
    end

    before { IronAdmin::AuditLog.clear! }

    context "with audit logging disabled" do
      before { get iron_admin.audit_path }

      it "warns in the theme's warning alert colors" do
        warning = document.css("p").find { |paragraph| paragraph.text.include?("Audit logging is currently disabled") }.parent
        expect(classes_of(warning)).to include("bg-amber-50", "border-amber-200", "text-amber-800", "border")
      end
    end

    context "with the default theme" do
      before do
        log_a_change
        get iron_admin.audit_path
      end

      it "renders the action as a badge in the theme's palette" do
        expect(classes_of(action_badge)).to include("bg-emerald-50", "rounded-md")
      end

      it "styles the header cells with the header cell classes" do
        expect(document.at_css("thead th")[:class]).to eq(styles.header_cell(neutral))
      end

      it "writes the new value of a change in the theme's success text color" do
        expect(document.css("details span").pluck(:class)).to include("text-emerald-700")
      end
    end

    context "with a registered theme active" do
      include_context "with the midnight theme"

      before do
        log_a_change
        get iron_admin.audit_path
      end

      it "writes the header cells with that theme's label transform" do
        expect(classes_of(document.at_css("thead th"))).to include("uppercase", "tracking-wider")
      end

      it "uses that theme's badge palette" do
        expect(classes_of(action_badge)).to include("bg-emerald-950")
      end
    end
  end
end
