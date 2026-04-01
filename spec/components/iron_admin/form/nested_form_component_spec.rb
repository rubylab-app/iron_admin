# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Form::NestedFormComponent, type: :component do
  let(:user) { create(:user) }
  let(:reflection) { User.reflect_on_association(:licenses) }
  let(:fields) do
    [
      IronAdmin::Field.new(:license_key, type: :text),
      IronAdmin::Field.new(:license_type, type: :text),
    ]
  end

  let(:nested_association) do
    IronAdmin::NestedAssociation.new(
      name: :licenses,
      kind: :has_many,
      reflection: reflection,
      fields: fields,
      allow_destroy: true,
      position_field: nil
    )
  end

  let(:form_builder) { double("form_builder") }

  describe "#title" do
    subject(:component) do
      described_class.new(
        form: form_builder,
        nested_association: nested_association,
        record: user
      )
    end

    it "humanizes the association name" do
      expect(component.title).to eq("Licenses")
    end
  end

  describe "#show_add_button?" do
    context "when kind is has_many" do
      it "returns true" do
        component = described_class.new(
          form: form_builder,
          nested_association: nested_association,
          record: user
        )
        expect(component.show_add_button?).to be(true)
      end
    end

    context "when kind is has_one" do
      it "returns false" do
        has_one_assoc = IronAdmin::NestedAssociation.new(
          name: :profile,
          kind: :has_one,
          reflection: User.reflect_on_association(:profile),
          fields: [],
          allow_destroy: false,
          position_field: nil
        )
        component = described_class.new(
          form: form_builder,
          nested_association: has_one_assoc,
          record: user
        )
        expect(component.show_add_button?).to be(false)
      end
    end
  end

  describe "#sortable?" do
    context "when position_field is present" do
      it "returns true" do
        assoc = IronAdmin::NestedAssociation.new(
          name: :licenses,
          kind: :has_many,
          reflection: reflection,
          fields: fields,
          allow_destroy: true,
          position_field: :position
        )
        component = described_class.new(
          form: form_builder,
          nested_association: assoc,
          record: user
        )
        expect(component.sortable?).to be(true)
      end
    end

    context "when position_field is nil" do
      it "returns false" do
        component = described_class.new(
          form: form_builder,
          nested_association: nested_association,
          record: user
        )
        expect(component.sortable?).to be(false)
      end
    end
  end

  describe "#child_records" do
    context "with has_many" do
      it "returns existing children" do
        create(:license, user: user)
        create(:license, user: user)
        user.reload

        component = described_class.new(
          form: form_builder,
          nested_association: nested_association,
          record: user
        )
        expect(component.child_records.length).to eq(2)
      end

      it "returns empty array when no children" do
        component = described_class.new(
          form: form_builder,
          nested_association: nested_association,
          record: user
        )
        expect(component.child_records).to eq([])
      end
    end

    context "with has_one" do
      let(:has_one_assoc) do
        IronAdmin::NestedAssociation.new(
          name: :profile,
          kind: :has_one,
          reflection: User.reflect_on_association(:profile),
          fields: [IronAdmin::Field.new(:bio, type: :textarea)],
          allow_destroy: false,
          position_field: nil
        )
      end

      it "returns existing record in an array" do
        create(:profile, user: user, bio: "Hello")
        user.reload

        component = described_class.new(
          form: form_builder,
          nested_association: has_one_assoc,
          record: user
        )
        children = component.child_records
        expect(children.length).to eq(1)
        expect(children.first.bio).to eq("Hello")
      end

      it "returns a new instance when no record exists" do
        component = described_class.new(
          form: form_builder,
          nested_association: has_one_assoc,
          record: user
        )
        children = component.child_records
        expect(children.length).to eq(1)
        expect(children.first).to be_a(Profile)
        expect(children.first).to be_new_record
      end
    end

    context "with position_field sorting" do
      let(:positional_assoc) do
        IronAdmin::NestedAssociation.new(
          name: :licenses,
          kind: :has_many,
          reflection: reflection,
          fields: fields,
          allow_destroy: true,
          position_field: :max_devices
        )
      end

      it "sorts by position_field ascending" do
        l1 = create(:license, user: user, max_devices: 3)
        l2 = create(:license, user: user, max_devices: 1)
        l3 = create(:license, user: user, max_devices: 2)
        user.reload

        component = described_class.new(
          form: form_builder,
          nested_association: positional_assoc,
          record: user
        )
        ids = component.child_records.map(&:id)
        expect(ids).to eq([l2.id, l3.id, l1.id])
      end
    end
  end

  describe "#template_index" do
    it "returns NEW_RECORD_INDEX placeholder" do
      component = described_class.new(
        form: form_builder,
        nested_association: nested_association,
        record: user
      )
      expect(component.template_index).to eq("NEW_RECORD_INDEX")
    end
  end
end
