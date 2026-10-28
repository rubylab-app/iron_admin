require "rails_helper"
require_relative "../../../../app/components/iron_admin/dashboards/recent_table_component"

RSpec.describe IronAdmin::Dashboards::RecentTableComponent, type: :component do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  describe "#initialize" do
    it "stores resource_name" do
      component = described_class.new(resource_name: :user, records: [])

      expect(component.instance_variable_get(:@resource_name)).to eq(:user)
    end

    it "stores records" do
      records = [instance_double(User)]
      component = described_class.new(resource_name: :user, records: records)

      expect(component.instance_variable_get(:@records)).to eq(records)
    end
  end

  describe "#label" do
    it "returns humanized pluralized resource name" do
      component = described_class.new(resource_name: :user, records: [])

      expect(component.label).to eq("Users")
    end

    it "handles underscored names" do
      component = described_class.new(resource_name: :license_type, records: [])

      expect(component.label).to eq("License types")
    end
  end

  describe "#fields" do
    subject(:field_names) { described_class.new(resource_name: resource_name, records: []).fields.map(&:name) }

    context "when the resource declares index fields" do
      let(:resource_name) { :document }

      before { IronAdmin::ResourceRegistry.register(IronAdmin::Resources::DocumentResource) }

      it "uses the index fields" do
        expect(field_names).to eq(%i[id title published created_at])
      end
    end

    context "when the resource declares no index fields" do
      let(:resource_name) { :profile }

      before { IronAdmin::ResourceRegistry.register(IronAdmin::Resources::ProfileResource) }

      it "shows the id, the first short columns and the creation time, skipping long text" do
        expect(field_names).to eq(%i[id user website created_at])
      end
    end

    context "when a label column comes after other columns" do
      let(:resource_name) { :catalog_item }

      before do
        IronAdmin::ResourceRegistry.register(Class.new(IronAdmin::Resource) do
          self.model_class_override = Post

          def self.resource_name = "catalog_items"

          def self.resolved_fields
            [
              IronAdmin::Field.new(:id, type: :number),
              IronAdmin::Field.new(:sku, type: :text),
              IronAdmin::Field.new(:status, type: :select),
              IronAdmin::Field.new(:title, type: :text),
              IronAdmin::Field.new(:created_at, type: :datetime),
            ]
          end
        end)
      end

      it "shows the label column first" do
        expect(field_names).to eq(%i[id title sku created_at])
      end
    end

    context "when a short column is a password field" do
      let(:resource_name) { :credential }

      before do
        IronAdmin::ResourceRegistry.register(Class.new(IronAdmin::Resource) do
          self.model_class_override = Post

          def self.resource_name = "credentials"

          def self.resolved_fields
            [
              IronAdmin::Field.new(:id, type: :number),
              IronAdmin::Field.new(:api_token, type: :password),
              IronAdmin::Field.new(:title, type: :text),
              IronAdmin::Field.new(:created_at, type: :datetime),
            ]
          end
        end)
      end

      it "leaves the password field out" do
        expect(field_names).to eq(%i[id title created_at])
      end
    end

    context "when a field is hidden from the current user" do
      subject(:field_names) do
        described_class.new(resource_name: :staff_member, records: [], current_user: :viewer).fields.map(&:name)
      end

      before do
        IronAdmin::ResourceRegistry.register(Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.resource_name = "staff_members"

          field :email, visible: ->(user) { user == :admin }
        end)
      end

      it "leaves the field out" do
        expect(field_names).not_to include(:email)
      end
    end

    context "when resource does not exist in registry" do
      let(:resource_name) { :nonexistent }

      it "returns empty array" do
        expect(field_names).to eq([])
      end
    end
  end

  describe "#ordered_records" do
    subject(:ordered_ids) { described_class.new(resource_name: :post, records: records).ordered_records.map(&:id) }

    let!(:older) { create(:post, created_at: 2.days.ago) }
    let!(:newer) { create(:post, created_at: 1.hour.ago) }
    let!(:oldest) { create(:post, created_at: 1.week.ago) }

    context "with an unordered relation" do
      let(:records) { Post.limit(2) }

      it "lists the newest records first" do
        expect(ordered_ids).to eq([newer.id, older.id])
      end
    end

    context "when records share a creation time" do
      let(:records) { Post.all }

      before { Post.update_all(created_at: 1.day.ago) }

      it "lists the highest primary key first" do
        expect(ordered_ids).to eq([oldest.id, newer.id, older.id])
      end
    end

    context "when the model has no created_at column" do
      let(:records) { Post.all }

      before { allow(Post).to receive(:column_names).and_return(Post.column_names - ["created_at"]) }

      it "lists the highest primary key first" do
        expect(ordered_ids).to eq([oldest.id, newer.id, older.id])
      end
    end

    context "with a relation that is already ordered" do
      let(:records) { Post.order(:id) }

      it "keeps the given order" do
        expect(ordered_ids).to eq([older.id, newer.id, oldest.id])
      end
    end

    context "with an array" do
      let(:records) { [oldest, newer] }

      it "keeps the given order" do
        expect(ordered_ids).to eq([oldest.id, newer.id])
      end
    end
  end

  describe "rendering" do
    before do
      vc_test_controller.view_context.class.define_method(:heroicon) do |name, **_opts|
        "<svg class=\"heroicon-#{name}\"></svg>".html_safe
      end
    end

    it "renders with empty records" do
      result = render_inline(described_class.new(resource_name: :user, records: []))

      expect(result.to_html).to include("Users")
    end

    it "renders with records" do
      users = create_list(:user, 2)
      result = render_inline(described_class.new(resource_name: :user, records: users))

      expect(result.to_html).to include("Users")
    end

    context "when the index fields include a rich text field" do
      subject(:cell) do
        render_inline(described_class.new(resource_name: :rich_document, records: [document])).at_css("tbody td:last-child")
      end

      let(:document) { create(:document, content: "<h2>Agenda</h2><p>Plan the <strong>launch</strong></p>") }

      before do
        IronAdmin::ResourceRegistry.register(Class.new(IronAdmin::Resource) do
          self.model_class_override = Document

          def self.resource_name = "rich_documents"

          field :content, type: :rich_text
          index_fields :title, :content
        end)
      end

      it "shows its plain text without the content's markup" do
        expect(cell.inner_html.strip).to eq("Agenda Plan the launch")
      end

      # In a card 64rem wide or more, long text keeps one line in a column that takes the room
      # left, so it neither widens the table nor makes the rows taller.
      it "truncates it to one line in a wide card" do
        expect(cell[:class].split).to include("whitespace-nowrap", "@5xl:max-w-0", "@5xl:min-w-48", "@5xl:truncate")
      end

      it "does not wrap it" do
        expect(cell[:class].split).not_to include("@5xl:whitespace-normal")
      end
    end

    context "when the index fields include an association" do
      subject(:cell) do
        render_inline(described_class.new(resource_name: :keyed_license, records: [license])).at_css("tbody td:last-child")
      end

      let(:license) { create(:license) }

      before do
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
        IronAdmin::ResourceRegistry.register(Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.resource_name = "keyed_licenses"

          belongs_to :user, display: :email
          index_fields :license_key, :user
        end)
      end

      # An association label is short or long; in a wide card it wraps instead of widening the table.
      it "wraps it only in a wide card" do
        expect(cell[:class].split).to include("whitespace-nowrap", "@5xl:whitespace-normal")
      end
    end
  end

  describe "theme classes" do
    subject(:card) { render_inline(described_class.new(resource_name: :document, records: [document])).at_css("div") }

    let(:document) { create(:document, title: "Launch plan") }
    let(:theme) { IronAdmin.current_theme }
    let(:header) { card.at_css("th") }
    let(:id_cell) { card.at_css("tbody td") }
    let(:title_cell) { card.css("tbody td")[1] }

    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::DocumentResource)
      vc_test_controller.view_context.class.define_method(:heroicon) do |name, **_opts|
        "<svg class=\"heroicon-#{name}\"></svg>".html_safe
      end
    end

    context "with the default theme" do
      # HAML's dot syntax reads ".py-3.5" as the classes "py-3" and "5".
      it "keeps fractional sizes such as py-3.5 whole" do
        expect(card.css("[class]").flat_map { |node| node[:class].split }).not_to include(match(/\A\d+\z/))
      end

      it "frames the card with the theme's surface, border, radius and shadow" do
        expect(card[:class].split).to include(*%w[bg-white border border-zinc-200 rounded-lg shadow-xs])
      end

      it "titles the card with the theme's card_title" do
        expect(card.at_css("h2")[:class].split).to include(*theme.card_title.split)
      end

      # The title starts where the first column does, whatever the theme's density.
      it "pads the title row like the cells" do
        expect(card.at_css("h2").parent[:class].split).to include(*theme.table_cell_padding.split)
      end

      it "styles the header cells with the theme's table_header_text and table_cell_padding" do
        expect(header[:class].split).to include(*theme.table_header_text.split, *theme.table_cell_padding.split)
      end

      it "leaves the header case to the theme's label_transform" do
        expect(header[:class].split).not_to include("uppercase")
      end

      it "marks the header cells as column headers" do
        expect(header[:scope]).to eq("col")
      end

      it "pads the body cells with the theme's table_cell_padding" do
        expect(title_cell[:class].split).to include(*theme.table_cell_padding.split)
      end

      it "aligns the digits of numeric cells" do
        expect(id_cell[:class].split).to include("tabular-nums")
      end

      it "keeps proportional digits in text cells" do
        expect(title_cell[:class].split).not_to include("tabular-nums")
      end

      # On a narrow screen the table scrolls sideways instead of squeezing its columns.
      it "keeps every cell on one line" do
        expect([id_cell, title_cell].map { |cell| cell[:class].split }).to all(include("whitespace-nowrap"))
      end

      it "keeps short cells such as numbers on one line in a wide card too" do
        expect(id_cell[:class].split).not_to include("@5xl:whitespace-normal")
      end

      # The label column (a name or a title) is the one that gives way in a wide card.
      it "lets the label column wrap in a wide card" do
        expect(title_cell[:class].split).to include("@5xl:whitespace-normal")
      end

      it "fades the edge the table can still scroll toward" do
        expect(card.at_css("table").parent[:class].split).to include("overflow-x-auto", "cp-scroll-fade")
      end

      # The cells fit the card's own width, wherever a dashboard layout puts it.
      it "makes the card a size container for its cells" do
        expect(card[:class].split).to include("@container")
      end

      it "highlights rows with the theme's table_row_hover" do
        expect(card.at_css("tbody tr")[:class].split).to include(*theme.table_row_hover.split)
      end

      it "colors the row dividers with the theme's table_border" do
        expect(card.at_css("tbody")[:class].split).to include("divide-y", *theme.table_border.split)
      end
    end

    context "with a registered theme active for the request" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:harbor) do |t|
          t.border_width = "border-2"
          t.table_header_bg = "bg-slate-800"
          t.table_header_text = "text-xs font-bold text-slate-400"
          t.label_transform = "uppercase tracking-wider"
          t.table_cell_padding = "px-3 py-1.5"
          t.table_frame = "max-h-96"
        end
      end

      it "frames the card with that theme's border width" do
        expect(card[:class].split).to include("border-2")
      end

      it "fills the header row with that theme's table_header_bg" do
        expect(card.at_css("thead")[:class].split).to include("bg-slate-800")
      end

      it "styles the header cells with that theme's text and label_transform" do
        expect(header[:class].split).to include(*%w[text-xs font-bold text-slate-400 uppercase tracking-wider])
      end

      it "pads the cells with that theme's table_cell_padding" do
        expect(title_cell[:class].split).to include("px-3", "py-1.5")
      end

      it "adds that theme's table_frame to the table container" do
        expect(card.at_css("table").parent[:class].split).to include("max-h-96")
      end
    end

    context "with a theme that sets table_head_border" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:print) do |t|
          t.table_head_border = "divide-stone-900"
        end
      end

      it "draws the line under the head in that color" do
        expect(card.at_css("table")[:class].split).to include("divide-stone-900")
      end
    end
  end

  # The dashboard page title is the h1, so a widget title is an h2.
  describe "widget title" do
    subject(:headings) do
      render_inline(described_class.new(resource_name: :user, records: []))
        .css("h1, h2, h3, h4, h5, h6")
    end

    before do
      vc_test_controller.view_context.class.define_method(:heroicon) do |name, **_opts|
        "<svg class=\"heroicon-#{name}\"></svg>".html_safe
      end
    end

    it "is an h2, one level below the page title" do
      expect(headings.map { |heading| [heading.name, heading.text.squish] }).to eq([["h2", "Recent Users"]])
    end
  end
end
