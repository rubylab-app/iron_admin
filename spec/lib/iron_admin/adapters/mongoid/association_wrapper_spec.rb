# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/mongoid"

RSpec.describe IronAdmin::Adapters::Mongoid::AssociationWrapper do
  subject(:wrapper) { described_class.new(relation) }

  let(:relation) do
    double(
      name: "user",
      macro: :belongs_to,
      class_name: "User",
      foreign_key: "user_id",
      polymorphic?: false
    )
  end

  describe "#name" do
    it "returns the association name as a symbol" do
      expect(wrapper.name).to eq(:user)
    end
  end

  describe "#macro" do
    it "returns the association macro" do
      expect(wrapper.macro).to eq(:belongs_to)
    end

    context "when macro is :embeds_many" do
      let(:relation) do
        double(
          name: "addresses",
          macro: :embeds_many,
          class_name: "Address",
          polymorphic?: false
        )
      end

      it "normalizes to :has_many" do
        expect(wrapper.macro).to eq(:has_many)
      end
    end

    context "when macro is :embeds_one" do
      let(:relation) do
        double(
          name: "profile",
          macro: :embeds_one,
          class_name: "Profile",
          polymorphic?: false
        )
      end

      it "normalizes to :has_one" do
        expect(wrapper.macro).to eq(:has_one)
      end
    end

    context "when macro is :embedded_in" do
      let(:relation) do
        double(
          name: "parent",
          macro: :embedded_in,
          class_name: "Parent",
          foreign_key: "parent_id",
          polymorphic?: false
        )
      end

      it "normalizes to :belongs_to" do
        expect(wrapper.macro).to eq(:belongs_to)
      end
    end

    context "when macro is :has_and_belongs_to_many" do
      let(:relation) do
        double(
          name: "tags",
          macro: :has_and_belongs_to_many,
          class_name: "Tag",
          foreign_key: "tag_ids",
          polymorphic?: false
        )
      end

      it "preserves the macro" do
        expect(wrapper.macro).to eq(:has_and_belongs_to_many)
      end
    end
  end

  describe "#klass" do
    it "constantizes the class_name" do
      expect(wrapper.klass).to eq(User)
    end
  end

  describe "#foreign_key" do
    it "returns the foreign key as a string" do
      expect(wrapper.foreign_key).to eq("user_id")
    end

    context "when relation has no foreign_key" do
      let(:relation) do
        double("Mongoid::Association::Embedded", name: "addresses", macro: :embeds_many,
                                                 class_name: "Address", polymorphic?: false)
      end

      it "returns empty string" do
        expect(wrapper.foreign_key).to eq("")
      end
    end
  end

  describe "#polymorphic?" do
    context "when relation is polymorphic" do
      let(:relation) do
        double(
          name: "commentable",
          macro: :belongs_to,
          class_name: "Object",
          foreign_key: "commentable_id",
          polymorphic?: true
        )
      end

      it "returns true" do
        expect(wrapper).to be_polymorphic
      end
    end

    context "when relation is not polymorphic" do
      it "returns false" do
        expect(wrapper).not_to be_polymorphic
      end
    end

    context "when relation does not respond to polymorphic?" do
      let(:relation) do
        double("Mongoid::Association::Basic", name: "user", macro: :belongs_to,
                                              class_name: "User", foreign_key: "user_id")
      end

      it "returns false" do
        expect(wrapper).not_to be_polymorphic
      end
    end
  end

  describe "#foreign_type" do
    it "returns the type column name" do
      expect(wrapper.foreign_type).to eq("user_type")
    end
  end
end
