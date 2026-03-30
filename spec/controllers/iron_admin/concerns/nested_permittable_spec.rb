# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Concerns::NestedPermittable do
  let(:controller_class) do
    Class.new(IronAdmin::ApplicationController) do
      include IronAdmin::Concerns::NestedPermittable

      public :build_nested_permit_list, :nested_field_permit

      def iron_admin_current_user
        nil
      end
    end
  end

  let(:controller) { controller_class.new }

  describe "#build_nested_permit_list" do
    let(:fields) do
      [
        IronAdmin::Field.new(:license_key, type: :text),
        IronAdmin::Field.new(:status, type: :badge),
      ]
    end

    context "with allow_destroy: true" do
      let(:nested) do
        IronAdmin::NestedAssociation.new(
          name: :licenses,
          kind: :has_many,
          reflection: double("reflection"),
          fields: fields,
          allow_destroy: true,
          position_field: nil
        )
      end

      it "includes field names" do
        permit_list = controller.build_nested_permit_list(nested)
        expect(permit_list).to include(:license_key, :status)
      end

      it "includes :id for matching existing records" do
        expect(controller.build_nested_permit_list(nested)).to include(:id)
      end

      it "includes :_destroy" do
        expect(controller.build_nested_permit_list(nested)).to include(:_destroy)
      end
    end

    context "with allow_destroy: false" do
      let(:nested) do
        IronAdmin::NestedAssociation.new(
          name: :licenses,
          kind: :has_many,
          reflection: double("reflection"),
          fields: fields,
          allow_destroy: false,
          position_field: nil
        )
      end

      it "does not include :_destroy" do
        expect(controller.build_nested_permit_list(nested)).not_to include(:_destroy)
      end
    end

    context "with position_field" do
      let(:nested) do
        IronAdmin::NestedAssociation.new(
          name: :licenses,
          kind: :has_many,
          reflection: double("reflection"),
          fields: fields,
          allow_destroy: true,
          position_field: :position
        )
      end

      it "includes the position field" do
        expect(controller.build_nested_permit_list(nested)).to include(:position)
      end
    end

    context "with readonly fields" do
      let(:readonly_field) { IronAdmin::Field.new(:status, type: :badge, readonly: true) }
      let(:fields_with_readonly) { [IronAdmin::Field.new(:license_key, type: :text), readonly_field] }

      let(:nested) do
        IronAdmin::NestedAssociation.new(
          name: :licenses,
          kind: :has_many,
          reflection: double("reflection"),
          fields: fields_with_readonly,
          allow_destroy: true,
          position_field: nil
        )
      end

      it "excludes readonly fields" do
        permit_list = controller.build_nested_permit_list(nested)
        expect(permit_list).to include(:license_key)
        expect(permit_list).not_to include(:status)
      end
    end
  end

  describe "#nested_field_permit" do
    context "with a regular field" do
      let(:field) { IronAdmin::Field.new(:name, type: :text) }

      it "returns the field name" do
        expect(controller.nested_field_permit(field)).to eq(:name)
      end
    end

    context "with a belongs_to field" do
      let(:field) { IronAdmin::Field.new(:user, type: :belongs_to, foreign_key: :user_id) }

      it "returns the foreign key" do
        expect(controller.nested_field_permit(field)).to eq(:user_id)
      end
    end

    context "with a files field" do
      let(:field) { IronAdmin::Field.new(:attachments, type: :files) }

      it "returns a hash with array permit" do
        expect(controller.nested_field_permit(field)).to eq({ attachments: [] })
      end
    end
  end
end
