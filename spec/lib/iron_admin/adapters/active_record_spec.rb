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

    it "raises IronAdmin::RecordNotFound for missing records" do
      expect { adapter.find(-1) }.to raise_error(IronAdmin::RecordNotFound)
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

  describe "#build" do
    it "returns a new unsaved record" do
      record = adapter.build(name: "Test", email: "build@test.com")
      expect(record).to be_a(User)
      expect(record).to be_new_record
      expect(record.name).to eq("Test")
    end

    it "returns empty record with no args" do
      record = adapter.build
      expect(record).to be_a(User)
      expect(record).to be_new_record
    end
  end

  describe "#save" do
    it "persists a new record" do
      record = adapter.build(name: "Save Test", email: "save@test.com")
      expect(adapter.save(record)).to be(true)
      expect(record).to be_persisted
    end
  end

  describe "#update" do
    it "updates record attributes" do
      user = create(:user, name: "Old Name")
      result = adapter.update(user, name: "New Name")
      expect(result).to be(true)
      expect(user.reload.name).to eq("New Name")
    end
  end

  describe "#destroy!" do
    it "destroys a record" do
      user = create(:user)
      adapter.destroy!(user)
      expect(User.find_by(id: user.id)).to be_nil
    end
  end

  describe "#transaction" do
    it "wraps operations in a transaction" do
      user = create(:user, name: "Original")
      adapter.transaction do
        adapter.update(user, name: "Changed")
        raise ActiveRecord::Rollback
      end
      expect(user.reload.name).to eq("Original")
    end
  end

  describe "#search_column" do
    it "searches a column with LIKE" do
      create(:user, name: "Alice Smith")
      create(:user, name: "Bob Jones")
      result = adapter.search_column(adapter.all, :name, "Alice")
      expect(result.count).to eq(1)
      expect(result.first.name).to eq("Alice Smith")
    end
  end

  describe "#search_columns" do
    it "searches multiple columns with OR" do
      create(:user, name: "Alice", email: "bob@test.com")
      create(:user, name: "Carol", email: "alice@test.com")
      result = adapter.search_columns(adapter.all, %i[name email], "alice")
      expect(result.count).to eq(2)
    end
  end

  describe "#unscope_column" do
    it "removes a WHERE condition on the specified column" do
      scope = User.where(role: "admin", active: true)
      unscoped = adapter.unscope_column(scope, :role)
      expect(unscoped.to_sql).not_to include("role")
      expect(unscoped.to_sql).to include("active")
    end

    it "accepts string column names" do
      scope = User.where(role: "admin")
      unscoped = adapter.unscope_column(scope, "role")
      expect(unscoped.to_sql).not_to include("role")
    end
  end

  describe "#find_each" do
    it "iterates records in batches" do
      create_list(:user, 3)
      names = []
      adapter.find_each(adapter.all) { |user| names << user.name }
      expect(names.size).to eq(3)
    end
  end

  describe "#record_changes" do
    it "returns saved changes after update" do
      user = create(:user, name: "Old")
      user.update!(name: "New")
      changes = adapter.record_changes(user)
      expect(changes).to have_key("name")
    end
  end

  describe "#wrap_rollback" do
    it "converts IronAdmin::Rollback to ActiveRecord::Rollback" do
      user = create(:user, name: "Original")
      adapter.transaction do
        adapter.wrap_rollback do
          adapter.update(user, name: "Changed")
          raise IronAdmin::Rollback
        end
      end
      expect(user.reload.name).to eq("Original")
    end
  end

  describe "#query_builder_class" do
    it "returns the ActiveRecord query builder" do
      expect(adapter.query_builder_class).to eq(IronAdmin::Filters::ActiveRecordQueryBuilder)
    end
  end

  describe "#pagy_method" do
    it "returns :pagy" do
      expect(adapter.pagy_method).to eq(:pagy)
    end
  end

  describe "#cast_boolean" do
    it "casts 'true' to true" do
      expect(adapter.cast_boolean("true")).to be(true)
    end

    it "casts '1' to true" do
      expect(adapter.cast_boolean("1")).to be(true)
    end

    it "casts 'false' to false" do
      expect(adapter.cast_boolean("false")).to be(false)
    end

    it "casts '0' to false" do
      expect(adapter.cast_boolean("0")).to be(false)
    end
  end
end
