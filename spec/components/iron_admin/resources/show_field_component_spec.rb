require "rails_helper"
require "ostruct"
require_relative "../../../../app/components/iron_admin/resources/show_field_component"

RSpec.describe IronAdmin::Resources::ShowFieldComponent, type: :component do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  let(:user) { create(:user, name: "John Doe") }
  let(:field) { IronAdmin::Resources::UserResource.resolved_fields.find { |f| f.name == :name } }

  describe "#initialize" do
    it "stores field" do
      component = described_class.new(field: field, record: user)
      expect(component.field).to eq(field)
    end

    it "stores record" do
      component = described_class.new(field: field, record: user)
      expect(component.record).to eq(user)
    end
  end

  describe "#label" do
    it "humanizes field name" do
      component = described_class.new(field: field, record: user)
      expect(component.label).to eq("Name")
    end
  end

  describe "field visibility" do
    let(:current_user) { create(:user) }

    context "when field is visible" do
      let(:visible_field) { IronAdmin::Field.new(:name, visible: true) }

      it "renders the component" do
        component = described_class.new(field: visible_field, record: user, current_user: current_user)
        expect(component.render?).to be true
      end
    end

    context "when field is not visible" do
      let(:invisible_field) { IronAdmin::Field.new(:name, visible: false) }

      it "does not render the component" do
        component = described_class.new(field: invisible_field, record: user, current_user: current_user)
        expect(component.render?).to be false
      end
    end

    context "when field visibility is conditional" do
      it "renders when condition is true" do
        conditional_field = IronAdmin::Field.new(:name, visible: ->(u) { u.present? })
        component = described_class.new(field: conditional_field, record: user, current_user: current_user)
        expect(component.render?).to be true
      end

      it "does not render when condition is false" do
        conditional_field = IronAdmin::Field.new(:name, visible: ->(u) { u.nil? })
        component = described_class.new(field: conditional_field, record: user, current_user: current_user)
        expect(component.render?).to be false
      end
    end

    context "when current_user is nil" do
      let(:visible_field) { IronAdmin::Field.new(:name, visible: true) }
      let(:conditional_field) { IronAdmin::Field.new(:name, visible: ->(u) { u.nil? }) }

      it "renders when field is unconditionally visible" do
        component = described_class.new(field: visible_field, record: user)
        expect(component.render?).to be true
      end

      it "evaluates conditional visibility with nil user" do
        component = described_class.new(field: conditional_field, record: user)
        expect(component.render?).to be true
      end
    end

    context "when field type is hidden" do
      let(:hidden_field) { IronAdmin::Field.new(:secret_token, type: :hidden) }

      it "does not render the component" do
        component = described_class.new(field: hidden_field, record: user, current_user: current_user)
        expect(component.render?).to be false
      end
    end

    context "when field is not visible to user" do
      let(:admin_only_field) do
        IronAdmin::Field.new(
          :secret,
          type: :text,
          visible: ->(u) { u&.admin? }
        )
      end
      let(:regular_user) { OpenStruct.new(admin?: false) }

      it "renders nothing when user cannot see field" do
        component = described_class.new(field: admin_only_field, record: user, current_user: regular_user)
        result = render_inline(component)
        expect(result.to_html.strip).to be_empty
      end
    end
  end

  describe "rendered row" do
    subject(:row) do
      with_controller_class(IronAdmin::ApplicationController) do
        render_inline(described_class.new(field: field, record: user)).at_css("div")
      end
    end

    it "lays out the label and the value like the show page's detail rows" do
      expect(row[:class]).to eq(IronAdmin::Resources::Styles::DETAIL_ROW)
    end

    it "writes the label in the theme's muted text color" do
      expect(row.at_css("dt")[:class].split).to include("text-zinc-500")
    end

    it "writes the value in the theme's body text color" do
      expect(row.at_css("dd")[:class].split).to include("text-zinc-900")
    end

    context "with a registered theme active" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:midnight) { |t| t.body_text = "text-zinc-100" }
      end

      it "writes the value in that theme's body text color" do
        expect(row.at_css("dd")[:class].split).to include("text-zinc-100")
      end
    end

    context "with a theme that transforms field labels" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:loud) do |t|
          t.field_label_transform = "uppercase tracking-wider"
        end
      end

      it "transforms the label" do
        expect(row.at_css("dt")[:class].split).to include("uppercase", "tracking-wider")
      end
    end
  end
end
