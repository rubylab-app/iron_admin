require "rails_helper"

RSpec.describe IronAdmin::Concerns::ComponentOverridable do
  subject(:resource_class) { Class.new(IronAdmin::Resource) }

  let(:table_component) { Class.new(ViewComponent::Base) }

  describe ".component" do
    context "with a resource slot" do
      it "stores the override" do
        resource_class.component :table, table_component

        expect(resource_class.component_override(:table)).to eq(table_component)
      end
    end

    context "with a slot name given as a String" do
      it "stores the override under the Symbol" do
        resource_class.component "form", table_component

        expect(resource_class.component_override(:form)).to eq(table_component)
      end
    end

    context "with a class name" do
      it "resolves the name when the override is read" do
        stub_const("ComponentOverridableSpecTable", table_component)
        resource_class.component :table, "ComponentOverridableSpecTable"

        expect(resource_class.component_override(:table)).to eq(table_component)
      end
    end

    context "with a slot that can only be overridden globally" do
      it "raises an ArgumentError pointing at config.components" do
        expect { resource_class.component :navbar, table_component }
          .to raise_error(ArgumentError, /config\.components\.navbar/)
      end
    end

    context "with an unknown slot" do
      it "raises an ArgumentError listing the resource slots" do
        expect { resource_class.component :index, table_component }
          .to raise_error(ArgumentError, /Unknown resource component slot :index.*:table, :form, :filter_bar, :search/)
      end
    end

    context "with a class that is not a ViewComponent" do
      it "raises an ArgumentError" do
        expect { resource_class.component :table, Class.new }
          .to raise_error(ArgumentError, /:table must be a ViewComponent::Base subclass/)
      end
    end

    context "when a subclass overrides a slot" do
      it "leaves the parent resource unchanged" do
        Class.new(resource_class).component :table, table_component

        expect(resource_class.component_override(:table)).to be_nil
      end
    end
  end

  describe ".component_override" do
    context "without an override" do
      it "returns nil" do
        expect(resource_class.component_override(:table)).to be_nil
      end
    end
  end
end
