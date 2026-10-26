require "rails_helper"
require_relative "../../../../app/components/iron_admin/resources/related_list_component"

RSpec.describe IronAdmin::Resources::RelatedListComponent, type: :component do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  let(:association) do
    { name: :posts, resource: IronAdmin::Resources::UserResource, display: :name }
  end

  describe "#initialize" do
    it "stores association" do
      records = User.none
      component = described_class.new(association: association, records: records)
      expect(component.association).to eq(association)
    end

    it "defaults limit to 20" do
      records = User.none
      component = described_class.new(association: association, records: records)
      expect(component.limit).to eq(20)
    end

    it "accepts custom limit" do
      records = User.none
      component = described_class.new(association: association, records: records, limit: 10)
      expect(component.limit).to eq(10)
    end
  end

  describe "#title" do
    it "humanizes association name" do
      records = User.none
      component = described_class.new(association: association, records: records)
      expect(component.title).to eq("Posts")
    end
  end

  describe "#resource_name" do
    it "returns association resource name" do
      records = User.none
      component = described_class.new(association: association, records: records)
      expect(component.resource_name).to eq(IronAdmin::Resources::UserResource.resource_name)
    end
  end

  describe "#display_method" do
    it "returns association display method" do
      records = User.none
      component = described_class.new(association: association, records: records)
      expect(component.display_method).to eq(:name)
    end
  end

  describe "#render?" do
    it "returns false when records are empty" do
      records = User.none
      component = described_class.new(association: association, records: records)
      expect(component.render?).to be false
    end

    it "returns true when records exist" do
      create_list(:user, 2)
      records = User.all
      component = described_class.new(association: association, records: records)
      expect(component.render?).to be true
    end
  end

  describe "rendering" do
    let(:user) { create(:user) }
    let(:licenses_association) do
      { name: :licenses, reflection: User.reflect_on_association(:licenses),
        resource: license_resource, display: :license_key, }
    end
    let(:license_resource) { license_resource_with_filter(nil) }

    before { create(:license, user: user) }

    def license_resource_with_filter(filter_type)
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "RelatedLicenseResource"
        end

        def self.resource_name
          "licenses"
        end

        filter :user_id, type: filter_type if filter_type
      end
    end

    def render_list(association = licenses_association, records: user.licenses, **options)
      with_controller_class(IronAdmin::ApplicationController) do
        render_inline(described_class.new(association: association, records: records, **options))
      end
    end

    def view_all_href(...)
      render_list(...).css("a").find { |link| link.text.strip == "View all" }["href"]
    end

    it "wraps the table in a horizontal scroll container" do
      expect(render_list.css(".overflow-x-auto table")).not_to be_empty
    end

    it "labels the View all link from the locale" do
      allow(I18n).to receive(:t).and_call_original
      allow(I18n).to receive(:t).with("iron_admin.resources.show.view_all").and_return("Every license")

      expect(render_list.css("a").map { |link| link.text.strip }).to include("Every license")
    end

    context "without a parent record" do
      let(:license_resource) { license_resource_with_filter(:select) }

      it "links View all to the unfiltered index" do
        expect(view_all_href).to eq(resources_path("licenses"))
      end
    end

    context "when the associated resource has a select filter on the foreign key" do
      let(:license_resource) { license_resource_with_filter(:select) }

      it "links View all to the index filtered by the parent" do
        expect(view_all_href(parent: user)).to eq(resources_path("licenses", filters: { user_id: user.id }))
      end
    end

    context "when the associated resource has a number filter on the foreign key" do
      let(:license_resource) { license_resource_with_filter(:number) }

      it "links View all to the index filtered with the equals operator" do
        expected = resources_path("licenses", filters: { user_id: { op: "equals", value: user.id } })

        expect(view_all_href(parent: user)).to eq(expected)
      end
    end

    context "when the associated resource has no filter on the foreign key" do
      it "links View all to the unfiltered index" do
        expect(view_all_href(parent: user)).to eq(resources_path("licenses"))
      end
    end

    context "with a polymorphic association" do
      let(:note_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = Note

          def self.name
            "RelatedNoteResource"
          end

          def self.resource_name
            "notes"
          end

          filter :notable_id, type: :select
        end
      end
      let(:notes_association) do
        { name: :notes, reflection: User.reflect_on_association(:notes), resource: note_resource, display: :title }
      end

      before { Note.create!(title: "Call back", notable: user) }

      it "links View all to the unfiltered index, since the id alone would match other parent types" do
        expect(view_all_href(notes_association, records: user.notes, parent: user))
          .to eq(resources_path("notes"))
      end
    end
  end
end
