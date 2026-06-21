require "rails_helper"
require "ostruct"
require_relative "../../../../app/components/iron_admin/resources/data_table_component"

RSpec.describe IronAdmin::Resources::DataTableComponent, type: :component do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  let(:users) { create_list(:user, 3) }
  let(:fields) { IronAdmin::Resources::UserResource.resolved_fields.first(3) }

  describe "#initialize" do
    it "stores records" do
      component = described_class.new(
        records: users,
        fields: fields,
        resource_class: IronAdmin::Resources::UserResource,
        base_url: "/admin/users?"
      )
      expect(component.records).to eq(users)
    end

    it "stores fields" do
      component = described_class.new(
        records: users,
        fields: fields,
        resource_class: IronAdmin::Resources::UserResource,
        base_url: "/admin/users?"
      )
      expect(component.fields).to eq(fields)
    end

    it "stores resource_class" do
      component = described_class.new(
        records: users,
        fields: fields,
        resource_class: IronAdmin::Resources::UserResource,
        base_url: "/admin/users?"
      )
      expect(component.resource_class).to eq(IronAdmin::Resources::UserResource)
    end
  end

  describe "#row_dom_id" do
    it "returns stable row ids for live replacement targets" do
      user = users.first
      component = described_class.new(
        records: users,
        fields: fields,
        resource_class: IronAdmin::Resources::UserResource,
        base_url: "/admin/users?"
      )

      expect(component.row_dom_id(user)).to eq("iron_admin_users_row_#{user.id}")
    end
  end

  describe "#empty?" do
    it "returns true when records are empty" do
      component = described_class.new(
        records: [],
        fields: fields,
        resource_class: IronAdmin::Resources::UserResource,
        base_url: "/admin/users?"
      )
      expect(component.empty?).to be true
    end

    it "returns false when records exist" do
      component = described_class.new(
        records: users,
        fields: fields,
        resource_class: IronAdmin::Resources::UserResource,
        base_url: "/admin/users?"
      )
      expect(component.empty?).to be false
    end
  end

  describe "#sort_url" do
    it "returns URL with sort params" do
      component = described_class.new(
        records: users,
        fields: fields,
        resource_class: IronAdmin::Resources::UserResource,
        base_url: "/admin/users?"
      )
      expect(component.sort_url(:name)).to include("sort=name")
      expect(component.sort_url(:name)).to include("direction=asc")
    end

    it "toggles direction when already sorted asc" do
      component = described_class.new(
        records: users,
        fields: fields,
        resource_class: IronAdmin::Resources::UserResource,
        current_sort: "name",
        current_direction: "asc",
        base_url: "/admin/users?"
      )
      expect(component.sort_url(:name)).to include("direction=desc")
    end
  end

  describe "#sorted?" do
    it "returns true when field matches current_sort" do
      component = described_class.new(
        records: users,
        fields: fields,
        resource_class: IronAdmin::Resources::UserResource,
        current_sort: "name",
        base_url: "/admin/users?"
      )
      expect(component.sorted?(:name)).to be true
    end

    it "returns false when field does not match" do
      component = described_class.new(
        records: users,
        fields: fields,
        resource_class: IronAdmin::Resources::UserResource,
        current_sort: "email",
        base_url: "/admin/users?"
      )
      expect(component.sorted?(:name)).to be false
    end
  end

  describe "#visible_fields" do
    let(:current_user) { create(:user) }
    let(:visible_field) { IronAdmin::Field.new(:name, visible: true) }
    let(:invisible_field) { IronAdmin::Field.new(:email, visible: false) }
    let(:conditional_visible_field) { IronAdmin::Field.new(:role, visible: ->(user) { user.present? }) }
    let(:conditional_invisible_field) { IronAdmin::Field.new(:secret, visible: ->(user) { user.nil? }) }
    let(:mixed_fields) { [visible_field, invisible_field, conditional_visible_field, conditional_invisible_field] }

    it "filters out fields where visible? returns false" do
      component = described_class.new(
        records: users,
        fields: mixed_fields,
        resource_class: IronAdmin::Resources::UserResource,
        current_user: current_user,
        base_url: "/admin/users?"
      )
      expect(component.visible_fields).to contain_exactly(visible_field, conditional_visible_field)
    end

    it "includes all fields when all are visible" do
      all_visible = [visible_field, conditional_visible_field]
      component = described_class.new(
        records: users,
        fields: all_visible,
        resource_class: IronAdmin::Resources::UserResource,
        current_user: current_user,
        base_url: "/admin/users?"
      )
      expect(component.visible_fields).to contain_exactly(visible_field, conditional_visible_field)
    end

    it "returns empty array when no fields are visible" do
      no_visible = [invisible_field, conditional_invisible_field]
      component = described_class.new(
        records: users,
        fields: no_visible,
        resource_class: IronAdmin::Resources::UserResource,
        current_user: current_user,
        base_url: "/admin/users?"
      )
      expect(component.visible_fields).to be_empty
    end

    it "defaults to nil current_user when not provided" do
      # When current_user is nil, conditional_invisible_field (visible: ->(user) { user.nil? }) should be visible
      conditional_field = IronAdmin::Field.new(:secret, visible: ->(user) { user.nil? })
      component = described_class.new(
        records: users,
        fields: [visible_field, conditional_field],
        resource_class: IronAdmin::Resources::UserResource,
        base_url: "/admin/users?"
      )
      expect(component.visible_fields).to contain_exactly(visible_field, conditional_field)
    end

    context "when field has visibility restriction" do
      let(:admin_user) { OpenStruct.new(admin?: true) }
      let(:regular_user) { OpenStruct.new(admin?: false) }
      let(:field_with_visibility) do
        IronAdmin::Field.new(
          :salary,
          type: :number,
          visible: ->(user) { user&.admin? }
        )
      end

      it "shows field when user has visibility permission" do
        component = described_class.new(
          records: users,
          fields: [visible_field, field_with_visibility],
          resource_class: IronAdmin::Resources::UserResource,
          current_user: admin_user,
          base_url: "/admin/users?"
        )
        expect(component.visible_fields).to contain_exactly(visible_field, field_with_visibility)
      end

      it "hides field when user lacks visibility permission" do
        component = described_class.new(
          records: users,
          fields: [visible_field, field_with_visibility],
          resource_class: IronAdmin::Resources::UserResource,
          current_user: regular_user,
          base_url: "/admin/users?"
        )
        expect(component.visible_fields).to contain_exactly(visible_field)
      end
    end
  end
end
