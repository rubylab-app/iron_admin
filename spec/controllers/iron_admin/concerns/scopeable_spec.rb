# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Concerns::Scopeable do
  subject(:controller) { controller_class.new }

  let(:controller_class) do
    Class.new do
      include IronAdmin::Concerns::Scopeable

      public :apply_resource_scope
    end
  end

  let(:record_class) { Struct.new(:title, :status, keyword_init: true) }

  let(:criteria_class) do
    Class.new do
      attr_reader :records

      def initialize(records)
        @records = records
      end

      def where(condition)
        self.class.new(records.select { |record| matches?(record, condition) })
      end

      def merge(other)
        raise TypeError, "Mongoid criteria cannot merge Proc scopes" if other.is_a?(Proc)

        self.class.new(records & other.records)
      end

      private

      def matches?(record, condition)
        condition.all? { |field, expected| record.public_send(field) == expected }
      end
    end
  end

  describe "#apply_resource_scope" do
    it "executes zero-arity proc scopes against the current Mongoid criteria" do
      records = [
        record_class.new(title: "Draft", status: "draft"),
        record_class.new(title: "Published", status: "published"),
      ]
      scope = criteria_class.new(records)

      result = controller.apply_resource_scope(scope, -> { where(status: "draft") })

      expect(result.records.map(&:title)).to contain_exactly("Draft")
    end
  end
end
