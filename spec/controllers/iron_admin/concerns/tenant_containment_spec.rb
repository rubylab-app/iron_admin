# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Concerns::TenantContainment, type: :lib do
  before do
    allow(IronAdmin::TenantScope).to receive(:configured?).and_return(true)
  end

  it "yields for a create when the record is inside the tenant" do
    adapter, state = build_adapter(verdict: :inside)
    record, _messages = build_record

    result = build_host(adapter).write(record) { :saved }

    expect(result).to eq(:saved)
    expect(state[:transaction]).to be(false)
    expect(state[:record]).to equal(record)
    expect(state[:scope]).to eq(:tenant_base_scope)
  end

  it "previews an update and yields when that copy is inside the tenant" do
    stand_in = Object.new
    adapter, state = build_adapter(verdict: :inside, preview: stand_in)
    record, _messages = build_record

    result = build_host(adapter).write(record, { "name" => "New" }) { :saved }

    expect(result).to eq(:saved)
    expect(state[:preview]).to be(true)
    expect(state[:record]).to equal(stand_in)
    expect(state[:transaction]).to be(false)
  end

  it "rejects an outside record without yielding" do
    adapter, state = build_adapter(verdict: :outside)
    record, messages = build_record
    yielded = false

    result = build_host(adapter).write(record) { yielded = true }

    expect(result).to be(false)
    expect(yielded).to be(false)
    expect(state[:transaction]).to be(false)
    expect(messages[:base]).to eq(["This change would put the record outside your tenant."])
  end

  it "rejects an unverifiable record without yielding" do
    adapter, state = build_adapter(verdict: :unknown)
    record, messages = build_record
    yielded = false

    result = build_host(adapter).write(record) { yielded = true }

    expect(result).to be(false)
    expect(yielded).to be(false)
    expect(state[:transaction]).to be(false)
    expect(messages[:base]).to eq(
      ["This change cannot be checked against your tenant, so it was not saved."]
    )
  end

  it "keeps the transactional path when the adapter can roll back" do
    adapter, state = build_adapter(verdict: :outside, transactions: true)
    record, _messages = build_record
    yielded = false

    result = build_host(adapter).write(record) do
      yielded = true
      true
    end

    expect(result).to be(true)
    expect(yielded).to be(true)
    expect(state[:transaction]).to be(true)
    expect(state[:record]).to be_nil
  end

  it "rejects a nested row that sits outside the tenant without yielding" do
    nested_candidate = Object.new
    record, messages = build_record
    child = double("child", id: 4)
    allow(record).to receive(:notes).and_return([child])
    adapter, state = build_nested_adapter(record:, nested_candidate:, nested_verdict: :outside)
    nested = build_nested_association(name: :notes, kind: :has_many)
    attrs = { "notes_attributes" => { "0" => { "id" => "4", "body" => "x" } } }
    yielded = false

    result = build_host(adapter, nested: [nested]).write(record, attrs) { yielded = true }

    expect(result).to be(false)
    expect(yielded).to be(false)
    expect(messages[:base]).to eq(["This change would put the record outside your tenant."])
    expect(state[:nested_matches]).to eq(1)
  end

  it "yields when every nested row is inside the tenant" do
    nested_candidate = Object.new
    record, _messages = build_record
    adapter, state = build_nested_adapter(record:, nested_candidate:, nested_verdict: :inside)
    nested = build_nested_association(name: :profile, kind: :has_one)
    submitted = { "profile_attributes" => { "body" => "inside" } }

    result = build_host(adapter, nested: [nested]).write(record, nil, submitted) { :saved }

    expect(result).to eq(:saved)
    expect(state[:builds]).to eq(1)
    expect(state[:nested_matches]).to eq(1)
  end

  it "ignores a nested row marked _destroy" do
    nested_candidate = Object.new
    record, _messages = build_record
    adapter, state = build_nested_adapter(record:, nested_candidate:, nested_verdict: :inside)
    nested = build_nested_association(name: :notes, kind: :has_many)
    attrs = {
      "notes_attributes" => [
        { "_destroy" => "1", "body" => "gone" },
        { "body" => "kept" },
      ],
    }

    result = build_host(adapter, nested: [nested]).write(record, attrs) { :saved }

    expect(result).to eq(:saved)
    expect(state[:builds]).to eq(1)
    expect(state[:nested_matches]).to eq(1)
  end

  def build_record
    messages = Hash.new { |hash, key| hash[key] = [] }
    errors = double("errors")
    allow(errors).to receive(:add) { |attribute, message| messages[attribute] << message }
    allow(errors).to receive(:[]) { |attribute| messages[attribute] }
    [double("record", id: "1", errors: errors), messages]
  end

  def build_adapter(verdict:, transactions: false, preview: nil)
    state = { preview: false, transaction: false, record: nil, scope: nil }
    adapter = double("adapter")
    allow(adapter).to receive_messages(supports_transactions?: transactions, primary_key: :id)
    allow(adapter).to receive(:scope_match) do |scope, candidate|
      state[:scope] = scope
      state[:record] = candidate
      verdict
    end
    allow(adapter).to receive(:preview) do |_record, _attrs|
      state[:preview] = true
      preview
    end
    allow(adapter).to receive(:transaction) do |&block|
      state[:transaction] = true
      block.call
    end
    allow(adapter).to receive(:wrap_rollback) do |&block|
      block.call
    rescue IronAdmin::Rollback
      nil
    end
    [adapter, state]
  end

  def build_host(adapter, nested: nil)
    associations = nested || []
    resource = Class.new
    resource.define_singleton_method(:nested_associations) { associations }
    host = Class.new do
      include IronAdmin::Concerns::TenantContainment

      def initialize(adapter, resource)
        @adapter = adapter
        @resource_class = resource
      end

      def write(record, attrs = nil, nested_attrs = nil, &block)
        write_within_tenant(record, attrs, nested_attrs, &block)
      end

      private

      attr_reader :adapter

      def base_scope
        :tenant_base_scope
      end

      def find_record(_scope, _id)
        :found
      end
    end
    host.new(adapter, resource)
  end

  def build_nested_adapter(record:, nested_candidate:, nested_verdict:)
    parent_copy = Object.new
    destroy_candidate = Object.new
    state = { builds: 0, nested_matches: 0 }
    adapter = double("adapter")
    allow(IronAdmin::TenantScope).to receive(:apply) { |scope| scope }
    allow(adapter).to receive_messages(supports_transactions?: false, primary_key: :id)
    allow(adapter).to receive(:preview) do |target, _attrs|
      target.equal?(record) ? parent_copy : nested_candidate
    end
    allow(adapter).to receive(:build_in) do |_scope, row|
      state[:builds] += 1
      if row.is_a?(Hash) && ActiveModel::Type::Boolean.new.cast(row["_destroy"])
        destroy_candidate
      else
        nested_candidate
      end
    end
    allow(adapter).to receive(:scope_match) do |_scope, candidate|
      if candidate.equal?(destroy_candidate)
        :outside
      elsif candidate.equal?(nested_candidate)
        state[:nested_matches] += 1
        nested_verdict
      else
        :inside
      end
    end
    [adapter, state]
  end

  def build_nested_association(name:, kind:)
    klass = Class.new do
      def self.all = :nested_child_scope
    end
    reflection = double("reflection", klass: klass)
    double("association", name: name, kind: kind, reflection: reflection)
  end
end
