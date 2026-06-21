# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/mongoid"

# Mongoid is not available in the test environment, so we use doubles
# to simulate Mongoid model behavior. This tests the adapter's logic
# without requiring a MongoDB connection.
RSpec.describe IronAdmin::Adapters::Mongoid do
  # Stub a Mongoid-like model class
  subject(:adapter) { described_class.new(model_class) }

  let(:model_class) do
    fields = {
      "_id" => double("Field", name: "_id", type: Object),
      "name" => double("Field", name: "name", type: String),
      "email" => double("Field", name: "email", type: String),
      "age" => double("Field", name: "age", type: Integer),
      "score" => double("Field", name: "score", type: Float),
      "active" => double("Field", name: "active", type: mongoid_boolean_class),
      "birthday" => double("Field", name: "birthday", type: Date),
      "created_at" => double("Field", name: "created_at", type: DateTime),
      "metadata" => double("Field", name: "metadata", type: Hash),
    }

    belongs_to_rel = double(
      "BelongsToRelation",
      name: "organization",
      macro: :belongs_to,
      class_name: "Organization",
      foreign_key: "organization_id",
      polymorphic?: false
    )

    has_many_rel = double(
      "HasManyRelation",
      name: "posts",
      macro: :has_many,
      class_name: "Post",
      foreign_key: "user_id",
      polymorphic?: false
    )

    embeds_many_rel = double(
      "EmbedsManyRelation",
      name: "addresses",
      macro: :embeds_many,
      class_name: "Address",
      polymorphic?: false
    )

    relations = {
      "organization" => belongs_to_rel,
      "posts" => has_many_rel,
      "addresses" => embeds_many_rel,
    }

    model_name = double("ModelName", plural: "users", human: "User")
    collection_name = double("CollectionName", to_s: "users")

    klass = double(
      "MongoidModel",
      fields: fields,
      relations: relations,
      model_name: model_name,
      collection_name: collection_name
    )

    # Allow Mongoid-specific method checks
    allow(klass).to receive(:respond_to?).and_return(false)
    allow(klass).to receive(:respond_to?).with(:attachment_reflections).and_return(false)
    allow(klass).to receive(:respond_to?).with(:rich_text_association_names).and_return(false)
    allow(klass).to receive(:respond_to?).with(:defined_enums).and_return(false)

    klass
  end

  let(:mongoid_boolean_class) do
    Class.new do
      def self.name
        "Mongoid::Boolean"
      end
    end
  end

  # --- Schema Introspection ---

  describe "#columns" do
    it "returns an array" do
      expect(adapter.columns).to be_an(Array)
    end

    it "returns descriptors that respond to name" do
      expect(adapter.columns.first).to respond_to(:name)
    end

    it "returns descriptors that respond to type" do
      expect(adapter.columns.first).to respond_to(:type)
    end

    it "maps String fields to :string type" do
      col = adapter.columns.find { |c| c.name == "name" }
      expect(col.type).to eq(:string)
    end

    it "maps Integer fields to :integer type" do
      col = adapter.columns.find { |c| c.name == "age" }
      expect(col.type).to eq(:integer)
    end

    it "maps Float fields to :float type" do
      col = adapter.columns.find { |c| c.name == "score" }
      expect(col.type).to eq(:float)
    end

    it "maps Boolean fields to :boolean type" do
      col = adapter.columns.find { |c| c.name == "active" }
      expect(col.type).to eq(:boolean)
    end

    it "maps Date fields to :date type" do
      col = adapter.columns.find { |c| c.name == "birthday" }
      expect(col.type).to eq(:date)
    end

    it "maps DateTime fields to :datetime type" do
      col = adapter.columns.find { |c| c.name == "created_at" }
      expect(col.type).to eq(:datetime)
    end

    it "maps Hash fields to :json type" do
      col = adapter.columns.find { |c| c.name == "metadata" }
      expect(col.type).to eq(:json)
    end

    it "maps _id field to :string type" do
      col = adapter.columns.find { |c| c.name == "_id" }
      expect(col.type).to eq(:string)
    end

    it "maps unknown types to :text" do
      unknown_field = double("Field", name: "custom", type: Class.new)
      allow(model_class).to receive(:fields).and_return("custom" => unknown_field)
      col = adapter.columns.first
      expect(col.type).to eq(:text)
    end
  end

  describe "#column_names" do
    it "returns array of field name strings" do
      expect(adapter.column_names).to include("_id", "name", "email", "age")
    end
  end

  describe "#has_column?" do
    it "returns true for existing fields" do
      expect(adapter.has_column?(:name)).to be(true)
    end

    it "returns false for non-existing fields" do
      expect(adapter.has_column?(:nonexistent)).to be(false)
    end

    it "accepts string arguments" do
      expect(adapter.has_column?("email")).to be(true)
    end
  end

  describe "#enums" do
    it "returns empty hash when model has no enums" do
      expect(adapter.enums).to eq({})
    end
  end

  describe "#associations" do
    it "returns all associations when no kind specified" do
      assocs = adapter.associations
      expect(assocs.length).to eq(3)
    end

    it "filters by :belongs_to" do
      assocs = adapter.associations(:belongs_to)
      expect(assocs.length).to eq(1)
      expect(assocs.first.name).to eq(:organization)
    end

    it "filters by :has_many including normalized embeds_many" do
      expect(adapter.associations(:has_many).length).to eq(2)
    end

    it "returns AssociationWrapper instances" do
      assocs = adapter.associations
      expect(assocs.first).to be_a(IronAdmin::Adapters::Mongoid::AssociationWrapper)
    end
  end

  describe "#association" do
    it "returns a wrapper for existing associations" do
      assoc = adapter.association(:organization)
      expect(assoc).not_to be_nil
      expect(assoc.name).to eq(:organization)
    end

    it "returns nil for non-existing associations" do
      expect(adapter.association(:nonexistent)).to be_nil
    end
  end

  describe "#polymorphic_inverse_classes" do
    it "returns Mongoid document classes with a matching polymorphic inverse relation" do
      stub_const("Mongoid::Document", Module.new)

      relation = double(
        "MongoidPolymorphicInverse",
        macro: :has_many,
        options: { as: :notable }
      )

      matching_class = Class.new do
        include Mongoid::Document

        define_singleton_method(:relations) { { "notes" => relation } }
      end
      non_matching_class = Class.new do
        include Mongoid::Document

        define_singleton_method(:relations) { {} }
      end
      stub_const("MongoidTarget", matching_class)
      stub_const("MongoidNonTarget", non_matching_class)

      expect(adapter.polymorphic_inverse_classes(:notable)).to include(MongoidTarget)
      expect(adapter.polymorphic_inverse_classes(:notable)).not_to include(MongoidNonTarget)
    end
  end

  describe "#attachments" do
    it "returns empty hash" do
      expect(adapter.attachments).to eq({})
    end
  end

  describe "#rich_text_attributes" do
    it "returns empty array" do
      expect(adapter.rich_text_attributes).to eq([])
    end
  end

  # --- Naming ---

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
    it "returns the collection name" do
      expect(adapter.table_name).to eq("users")
    end
  end

  # --- Query Building ---

  describe "#all" do
    it "calls all on the model class" do
      scope = double("Criteria")
      allow(model_class).to receive(:all).and_return(scope)
      expect(adapter.all).to eq(scope)
    end
  end

  describe "#find" do
    it "delegates to model_class.find" do
      record = double("Record")
      allow(model_class).to receive(:find).with("abc123").and_return(record)
      expect(adapter.find("abc123")).to eq(record)
    end

    it "raises IronAdmin::RecordNotFound when record is missing" do
      allow(model_class).to receive(:find).and_raise(StandardError.new("not found"))
      expect { adapter.find("bad_id") }.to raise_error(IronAdmin::RecordNotFound)
    end
  end

  describe "#find_by" do
    it "delegates to model_class.find_by" do
      record = double("Record")
      allow(model_class).to receive(:find_by).and_return(record)
      expect(adapter.find_by(email: "test@test.com")).to eq(record)
    end

    it "returns nil when not found" do
      allow(model_class).to receive(:find_by).and_return(nil)
      expect(adapter.find_by(email: "nope")).to be_nil
    end
  end

  describe "#filter" do
    it "applies where clause to scope" do
      scope = double("Criteria")
      filtered = double("FilteredCriteria")
      allow(scope).to receive(:where).with(role: "admin").and_return(filtered)
      expect(adapter.filter(scope, :role, "admin")).to eq(filtered)
    end
  end

  describe "#order_by" do
    it "applies ordering to scope" do
      scope = double("Criteria")
      ordered = double("OrderedCriteria")
      allow(scope).to receive(:order_by).with(name: :asc).and_return(ordered)
      expect(adapter.order_by(scope, :name, :asc)).to eq(ordered)
    end
  end

  describe "#limit" do
    it "limits the scope" do
      scope = double("Criteria")
      limited = double("LimitedCriteria")
      allow(scope).to receive(:limit).with(10).and_return(limited)
      expect(adapter.limit(scope, 10)).to eq(limited)
    end
  end

  describe "#preload" do
    it "includes associations on scope" do
      scope = double("Criteria")
      preloaded = double("PreloadedCriteria")
      allow(scope).to receive(:includes).with(:posts, :addresses).and_return(preloaded)
      expect(adapter.preload(scope, %i[posts addresses])).to eq(preloaded)
    end
  end

  describe "#distinct_values" do
    it "returns sorted unique values without nils" do
      allow(model_class).to receive(:distinct).with(:role).and_return(["member", nil, "admin"])
      values = adapter.distinct_values(:role)
      expect(values).to eq(%w[admin member])
    end
  end

  describe "#pluck" do
    it "extracts column values" do
      scope = double("Criteria")
      allow(scope).to receive(:pluck).with(:name).and_return(%w[Alice Bob])
      expect(adapter.pluck(scope, :name)).to eq(%w[Alice Bob])
    end
  end

  describe "#count" do
    it "counts records in a scope" do
      scope = double("Criteria", count: 5)
      expect(adapter.count(scope)).to eq(5)
    end

    it "defaults to all when no scope given" do
      scope = double("Criteria", count: 3)
      allow(model_class).to receive(:all).and_return(scope)
      expect(adapter.count).to eq(3)
    end
  end

  # --- Search ---

  describe "#search_column" do
    it "passes a case-insensitive regex to where" do
      scope = double("Criteria")
      filtered = double("FilteredCriteria")
      allow(scope).to receive(:where).and_return(filtered)
      result = adapter.search_column(scope, :name, "Alice")
      expect(result).to eq(filtered)
    end

    it "escapes regex metacharacters so dot is literal" do
      scope = double("Criteria")
      filtered = double("FilteredCriteria")
      allow(scope).to receive(:where).and_return(filtered)
      adapter.search_column(scope, :name, "u.n")
      expect(scope).to have_received(:where) do |args|
        regex = args[:name]
        expect(regex).not_to match("uxn")
      end
    end
  end

  describe "#search_columns" do
    it "searches multiple columns with OR logic" do
      scope = double("Criteria")
      filtered = double("FilteredCriteria")
      allow(scope).to receive(:any_of).and_return(filtered)
      result = adapter.search_columns(scope, %i[name email], "alice")
      expect(result).to eq(filtered)
    end
  end

  # --- CRUD ---

  describe "#build" do
    it "creates a new unsaved record" do
      record = double("Record")
      allow(model_class).to receive(:new).and_return(record)
      expect(adapter.build(name: "Test")).to eq(record)
    end

    it "creates empty record with no args" do
      record = double("Record")
      allow(model_class).to receive(:new).and_return(record)
      expect(adapter.build).to eq(record)
    end
  end

  describe "#save" do
    it "saves the record" do
      record = double("Record", save: true)
      expect(adapter.save(record)).to be(true)
    end

    it "returns false on validation failure" do
      record = double("Record", save: false)
      expect(adapter.save(record)).to be(false)
    end
  end

  describe "#update" do
    it "updates record attributes" do
      record = double("Record")
      allow(record).to receive(:update).and_return(true)
      expect(adapter.update(record, name: "New")).to be(true)
    end
  end

  describe "#destroy!" do
    it "destroys the record" do
      record = double("Record")
      allow(record).to receive(:destroy!).and_return(true)
      adapter.destroy!(record)
      expect(record).to have_received(:destroy!)
    end
  end

  # --- Transactions ---

  describe "#transaction" do
    it "yields the block" do
      result = adapter.transaction { "done" }
      expect(result).to eq("done")
    end
  end

  # --- Scope Manipulation ---

  describe "#unscope_column" do
    it "removes the column from the criteria selector" do
      scope = double("Criteria", selector: { "role" => "admin", "active" => true }, options: {})
      new_criteria = double("NewCriteria")
      allow(model_class).to receive(:where).with({ "active" => true }).and_return(new_criteria)
      result = adapter.unscope_column(scope, :role)
      expect(result).to eq(new_criteria)
    end

    it "accepts string column names" do
      scope = double("Criteria", selector: { "role" => "admin" }, options: {})
      new_criteria = double("NewCriteria")
      allow(model_class).to receive(:where).with({}).and_return(new_criteria)
      result = adapter.unscope_column(scope, "role")
      expect(result).to eq(new_criteria)
    end

    it "preserves ordering from original scope" do
      sort_opts = { "name" => 1 }
      scope = double("Criteria", selector: { "role" => "admin" }, options: { sort: sort_opts })
      base_criteria = double("BaseCriteria")
      ordered_criteria = double("OrderedCriteria")
      allow(model_class).to receive(:where).with({}).and_return(base_criteria)
      allow(base_criteria).to receive(:order_by).with(sort_opts).and_return(ordered_criteria)
      result = adapter.unscope_column(scope, :role)
      expect(result).to eq(ordered_criteria)
    end
  end

  # --- Batch ---

  describe "#find_each" do
    it "iterates records with batch_size" do
      records = [double("Record1"), double("Record2")]
      scope = double("Criteria")
      batched = double("BatchedCriteria")
      allow(scope).to receive(:batch_size).with(100).and_return(batched)
      allow(batched).to receive(:each).and_yield(records[0]).and_yield(records[1])

      collected = []
      adapter.find_each(scope) { |r| collected << r }
      expect(collected.length).to eq(2)
    end
  end

  # --- Adapter-Agnostic Interface ---

  describe "#record_changes" do
    it "returns previous_changes from the record" do
      record = double("Record", previous_changes: { "name" => %w[Old New] })
      expect(adapter.record_changes(record)).to eq("name" => %w[Old New])
    end
  end

  describe "#wrap_rollback" do
    it "yields the block normally" do
      result = adapter.wrap_rollback { "success" }
      expect(result).to eq("success")
    end

    it "silences IronAdmin::Rollback" do
      expect { adapter.wrap_rollback { raise IronAdmin::Rollback } }.not_to raise_error
    end
  end

  describe "#query_builder_class" do
    it "returns MongoidQueryBuilder" do
      expect(adapter.query_builder_class).to eq(IronAdmin::Filters::MongoidQueryBuilder)
    end
  end

  describe "#pagy_method" do
    it "returns :pagy_mongoid" do
      expect(adapter.pagy_method).to eq(:pagy_mongoid)
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

    it "casts empty string to false" do
      expect(adapter.cast_boolean("")).to be(false)
    end
  end
end
