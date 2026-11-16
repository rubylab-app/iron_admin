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

  it "builds a new nested row with the child model class" do
    record, _messages = build_record
    nested = build_nested_association(name: :profile, kind: :has_one)
    adapter, built = build_child_model_adapter(nested.reflection.klass)
    submitted = { "profile_attributes" => { "body" => "inside" } }

    result = build_host(adapter, nested: [nested]).write(record, nil, submitted) { :saved }

    expect(result).to eq(:saved)
    expect(built.map(&:model_class)).to eq([nested.reflection.klass])
  end

  it "reports tenant_unverifiable when the child adapter cannot be built" do
    record, messages = build_record
    nested = build_nested_association(name: :profile, kind: :has_one)
    adapter = build_raising_child_adapter(nested.reflection.klass)
    submitted = { "profile_attributes" => { "body" => "inside" } }
    yielded = false

    result = build_host(adapter, nested: [nested]).write(record, nil, submitted) { yielded = true }

    expect(result).to be(false)
    expect(yielded).to be(false)
    expect(messages[:base]).to eq(
      ["This change cannot be checked against your tenant, so it was not saved."]
    )
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
    state = { builds: 0, nested_matches: 0 }
    context = {
      record: record,
      nested_candidate: nested_candidate,
      nested_verdict: nested_verdict,
      parent_copy: Object.new,
      destroy_candidate: Object.new,
      state: state,
    }
    allow(IronAdmin::TenantScope).to receive(:apply) { |scope| scope }
    [nested_row_adapter_class(context).new, state]
  end

  def nested_row_adapter_class(context)
    klass = Class.new do
      def initialize(_model_class = nil) = nil

      def supports_transactions? = false

      def primary_key = :id
    end
    define_nested_row_preview(klass, context)
    define_nested_row_build(klass, context)
    define_nested_row_scope_match(klass, context)
    klass
  end

  def define_nested_row_preview(klass, context)
    klass.define_method(:preview) do |target, _attrs|
      target.equal?(context[:record]) ? context[:parent_copy] : context[:nested_candidate]
    end
  end

  def define_nested_row_build(klass, context)
    klass.define_method(:build_in) do |_scope, row|
      context[:state][:builds] += 1
      if row.is_a?(Hash) && ActiveModel::Type::Boolean.new.cast(row["_destroy"])
        context[:destroy_candidate]
      else
        context[:nested_candidate]
      end
    end
  end

  def define_nested_row_scope_match(klass, context)
    verdict = method(:nested_row_scope_verdict)
    klass.define_method(:scope_match) do |_scope, candidate|
      verdict.call(candidate, context)
    end
  end

  def nested_row_scope_verdict(candidate, context)
    return :outside if candidate.equal?(context[:destroy_candidate])
    return :inside unless candidate.equal?(context[:nested_candidate])

    context[:state][:nested_matches] += 1
    context[:nested_verdict]
  end

  def build_nested_association(name:, kind:)
    klass = Class.new do
      def self.all = :nested_child_scope
    end
    reflection = double("reflection", klass: klass)
    double("association", name: name, kind: kind, reflection: reflection)
  end

  def build_child_model_adapter(child_class)
    built = []
    adapter_class = Class.new do
      attr_reader :model_class

      def initialize(model_class)
        @model_class = model_class
      end

      def supports_transactions? = false

      def primary_key = :id

      def preview(target, _attrs) = target
    end
    remember_child_builds(adapter_class, built)
    match_child_model(adapter_class, child_class)
    allow(IronAdmin::TenantScope).to receive(:apply) { |scope| scope }
    [adapter_class.new(Class.new), built]
  end

  def remember_child_builds(adapter_class, built)
    row_struct = Struct.new(:model_class, :attrs)
    adapter_class.define_method(:build_in) do |_scope, attrs|
      row = row_struct.new(model_class, attrs)
      built << row
      row
    end
  end

  # Parent records have no model_class. A built row is inside only for the child class.
  def match_child_model(adapter_class, child_class)
    adapter_class.define_method(:scope_match) do |_scope, candidate|
      child_model = candidate.respond_to?(:model_class) && candidate.model_class.equal?(child_class)
      child_model || !candidate.respond_to?(:model_class) ? :inside : :outside
    end
  end

  def build_raising_child_adapter(child_class)
    adapter_class = Class.new do
      def supports_transactions? = false

      def primary_key = :id

      def build_in(_scope, _attrs) = Object.new

      def preview(_record, _attrs) = Object.new

      def scope_match(_scope, _candidate) = :inside
    end
    adapter_class.define_method(:initialize) do |model_class|
      raise StandardError, "child adapter unavailable" if model_class.equal?(child_class)

      @model_class = model_class
    end
    allow(IronAdmin::TenantScope).to receive(:apply) { |scope| scope }
    adapter_class.new(Class.new)
  end
end
