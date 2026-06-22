# frozen_string_literal: true

require "rails_helper"

RSpec.describe "IronAdmin Mongoid value handling", type: :request do
  let(:record_class) do
    Class.new do
      attr_accessor :_id, :title, :status, :views, :metadata, :tags, :created_at

      def initialize(attributes = {})
        attributes.each { |key, value| public_send("#{key}=", value) }
      end

      def id
        _id
      end

      def to_param
        _id.to_s
      end

      def update(attributes)
        attributes.each do |key, value|
          public_send("#{key}=", cast_value(key, value))
        end
      end

      def previous_changes
        {}
      end

      private

      def cast_value(key, value)
        return value unless key.to_s == "tags"

        value.is_a?(Array) ? value : nil
      end
    end
  end

  let(:criteria_class) do
    Class.new do
      include Enumerable

      attr_reader :records, :selector, :options

      def initialize(records, selector: {}, options: {})
        @records = records
        @selector = selector
        @options = options
      end

      def each(&)
        records.each(&)
      end

      def where(condition)
        matching_records = records.select { |record| matches?(record, condition) }
        self.class.new(matching_records, selector: selector.merge(condition), options: options)
      end

      def any_of(*conditions)
        matching_records = records.select do |record|
          conditions.any? { |condition| matches?(record, condition) }
        end
        self.class.new(matching_records, selector: selector, options: options)
      end

      def order_by(order)
        column, direction = order.first
        sorted = records.sort_by { |record| record.public_send(column) }
        sorted.reverse! if direction.to_s == "desc"
        self.class.new(sorted, selector: selector, options: options.merge(sort: order))
      end

      def limit(max)
        self.class.new(records.first(max), selector: selector, options: options)
      end

      def includes(*)
        self
      end

      def batch_size(_size)
        self
      end

      private

      def matches?(record, condition)
        condition.all? do |field, expected|
          value = record.public_send(field.to_s)
          matches_expected_value?(value, expected)
        end
      end

      def matches_expected_value?(value, expected)
        return value.to_s.match?(expected) if expected.is_a?(Regexp)
        return matches_operator_hash?(value, expected) if expected.is_a?(Hash)

        value == expected
      end

      def matches_operator_hash?(value, expected)
        expected.all? do |operator, bound|
          case operator
          when "$gt" then value > bound
          when "$gte" then value >= bound
          when "$lt" then value < bound
          when "$lte" then value <= bound
          end
        end
      end
    end
  end

  let(:model_class) do
    criteria = criteria_class
    field = Struct.new(:name, :type)

    Class.new do
      define_singleton_method(:records) { @records }
      define_singleton_method(:records=) { |records| @records = records }
      define_singleton_method(:relations) { {} }
      define_singleton_method(:collection_name) { "mongo_posts" }
      define_singleton_method(:model_name) { ActiveModel::Name.new(self, nil, "MongoPost") }
      define_singleton_method(:all) { criteria.new(records) }

      attr_accessor :title, :tags

      define_method(:initialize) do |attributes = {}|
        attributes.each { |key, value| public_send("#{key}=", value) }
      end

      define_singleton_method(:fields) do
        {
          "_id" => field.new("_id", Object),
          "title" => field.new("title", String),
          "status" => field.new("status", String),
          "views" => field.new("views", Integer),
          "metadata" => field.new("metadata", Hash),
          "tags" => field.new("tags", Array),
          "created_at" => field.new("created_at", Time),
        }
      end
    end
  end

  let(:resource_class) do
    model = model_class

    Class.new(IronAdmin::Resource) do
      self.adapter_class = :mongoid
      self.model_class_override = model

      def self.name
        "MongoidValueResource"
      end

      def self.resource_name
        "mongo_posts"
      end

      field :tags, type: :tags
      export_fields :title, :metadata, :tags
    end
  end

  before do
    model_class.records = [
      record_class.new(
        _id: "1",
        title: "Mongo Post",
        status: "draft",
        views: 7,
        metadata: { "source" => "mongoid", "nested" => { "published" => false } },
        tags: ["alpha"],
        created_at: 1.day.ago
      ),
    ]

    IronAdmin::ResourceRegistry.register(resource_class)
  end

  describe "GET /:resource_name/export.json" do
    it "keeps structured values as JSON objects and arrays" do
      get iron_admin.export_path("mongo_posts", format: :json)

      exported_record = response.parsed_body.first
      expect(exported_record["metadata"]).to eq(
        "source" => "mongoid",
        "nested" => { "published" => false }
      )
      expect(exported_record["tags"]).to eq(["alpha"])
    end
  end

  describe "PATCH /:resource_name/:id" do
    it "persists comma-separated tags as an Array for Mongoid array fields" do
      patch iron_admin.resource_path("mongo_posts", "1"),
            params: { record: { title: "Mongo Post", tags: "gamma,delta" } },
            as: :html

      expect(model_class.records.first.tags).to eq(%w[gamma delta])
    end
  end

  describe "Mongoid adapter" do
    it "builds records with comma-separated tags cast to an Array" do
      record = resource_class.adapter.build(title: "New Mongo Post", tags: "gamma,delta")

      expect(record.tags).to eq(%w[gamma delta])
    end
  end
end
