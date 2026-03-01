# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Adapters::ActiveRecord do
  subject(:adapter) { described_class.new(User) }

  describe "#columns" do
    it "returns column objects with name and type" do
      cols = adapter.columns
      expect(cols).to be_an(Array)
      expect(cols.first).to respond_to(:name)
      expect(cols.first).to respond_to(:type)
    end

    it "includes the name column" do
      names = adapter.columns.map(&:name)
      expect(names).to include("name")
    end
  end

  describe "#column_names" do
    it "returns array of strings" do
      expect(adapter.column_names).to include("name", "email", "role")
    end
  end

  describe "#has_column?" do
    it "returns true for existing columns" do
      expect(adapter.has_column?(:name)).to be(true)
    end

    it "returns false for non-existing columns" do
      expect(adapter.has_column?(:nonexistent)).to be(false)
    end
  end

  describe "#enums" do
    subject(:adapter) { described_class.new(License) }

    it "returns a hash of enum definitions" do
      enums = adapter.enums
      expect(enums).to be_a(Hash)
      expect(enums).to have_key("status")
    end
  end

  describe "#associations" do
    context "with User model" do
      it "returns has_many associations" do
        assocs = adapter.associations(:has_many)
        names = assocs.map(&:name)
        expect(names).to include(:licenses)
      end

      it "returns has_one associations" do
        assocs = adapter.associations(:has_one)
        names = assocs.map(&:name)
        expect(names).to include(:profile)
      end
    end

    context "with License model" do
      subject(:adapter) { described_class.new(License) }

      it "returns belongs_to associations" do
        assocs = adapter.associations(:belongs_to)
        names = assocs.map(&:name)
        expect(names).to include(:user)
      end
    end

    context "without kind filter" do
      it "returns all associations" do
        all_assocs = adapter.associations
        expect(all_assocs).not_to be_empty
      end
    end
  end

  describe "#association" do
    it "returns a single association by name" do
      assoc = adapter.association(:licenses)
      expect(assoc).not_to be_nil
      expect(assoc.name).to eq(:licenses)
    end

    it "returns nil for non-existing associations" do
      expect(adapter.association(:nonexistent)).to be_nil
    end
  end

  describe "#attachments" do
    subject(:adapter) { described_class.new(Document) }

    it "returns attachment reflections" do
      attachments = adapter.attachments
      expect(attachments.keys.map(&:to_s)).to include("cover_image")
    end
  end

  describe "#rich_text_attributes" do
    subject(:adapter) { described_class.new(Document) }

    it "returns rich text attribute names" do
      attrs = adapter.rich_text_attributes
      expect(attrs.map(&:to_s)).to include("rich_text_content")
    end
  end

  describe "#resource_name" do
    it "returns the plural model name" do
      expect(adapter.resource_name).to eq("users")
    end
  end

  describe "#human_name" do
    it "returns the humanized model name" do
      expect(adapter.human_name).to eq("User")
    end
  end

  describe "#table_name" do
    it "returns the database table name" do
      expect(adapter.table_name).to eq("users")
    end
  end

  describe "#all" do
    it "returns an ActiveRecord::Relation" do
      expect(adapter.all).to be_a(ActiveRecord::Relation)
    end
  end

  describe "#find" do
    it "finds a record by id" do
      user = create(:user)
      expect(adapter.find(user.id)).to eq(user)
    end

    it "raises RecordNotFound for missing records" do
      expect { adapter.find(-1) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#find_by" do
    it "finds a record by attributes" do
      user = create(:user, email: "findme@test.com")
      expect(adapter.find_by(email: "findme@test.com")).to eq(user)
    end

    it "returns nil when not found" do
      expect(adapter.find_by(email: "nope@test.com")).to be_nil
    end
  end

  describe "#filter" do
    it "filters scope by column value" do
      create(:user, role: "admin")
      create(:user, role: "member")
      scope = adapter.all
      filtered = adapter.filter(scope, :role, "admin")
      expect(filtered.count).to eq(1)
      expect(filtered.first.role).to eq("admin")
    end
  end

  describe "#order_by" do
    it "orders scope by column" do
      create(:user, name: "Zara")
      create(:user, name: "Alice")
      scope = adapter.all
      ordered = adapter.order_by(scope, :name, :asc)
      expect(ordered.first.name).to eq("Alice")
    end
  end

  describe "#limit" do
    it "limits the scope" do
      create_list(:user, 5)
      scope = adapter.all
      limited = adapter.limit(scope, 2)
      expect(limited.count).to eq(2)
    end
  end

  describe "#preload" do
    it "returns a scope with preloading" do
      scope = adapter.all
      result = adapter.preload(scope, [:licenses])
      expect(result).to be_a(ActiveRecord::Relation)
    end
  end

  describe "#distinct_values" do
    it "returns sorted unique values for a column" do
      create(:user, role: "admin")
      create(:user, role: "member")
      create(:user, role: "admin")
      values = adapter.distinct_values(:role)
      expect(values).to eq(%w[admin member])
    end
  end

  describe "#pluck" do
    it "extracts column values from a scope" do
      user = create(:user)
      ids = adapter.pluck(adapter.all, :id)
      expect(ids).to include(user.id)
    end
  end

  describe "#count" do
    it "counts records in a scope" do
      create_list(:user, 3)
      expect(adapter.count(adapter.all)).to eq(3)
    end

    it "counts all records without a scope" do
      create_list(:user, 2)
      expect(adapter.count).to eq(2)
    end
  end
end
