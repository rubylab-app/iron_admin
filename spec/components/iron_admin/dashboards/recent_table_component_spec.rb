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
