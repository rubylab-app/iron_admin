# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Concerns::PolymorphicReferences do
  it "holds the polymorphic assignable checks mixed into assignable references" do
    host = Class.new { include IronAdmin::Concerns::AssignableReferences }

    expect(described_class.private_instance_methods(false)).to include(
      :polymorphic_references_assignable?,
      :polymorphic_type_name
    )
    expect(host.ancestors).to include(described_class)
    expect(IronAdmin::Concerns::AssignableReferences.private_instance_methods(false)).not_to include(
      :polymorphic_references_assignable?
    )
  end

  it "treats a blank submitted id as assignable when the stored id is outside the tenant" do
    outsider = create(:user, role: "member")
    note = Note.new(notable_type: "User", notable_id: outsider.id)
    attrs = { "notable_id" => "" }.with_indifferent_access

    assignable = polymorphic_host.send(
      :polymorphic_field_assignable?,
      note,
      attrs,
      notable_polymorphic_field
    )

    expect(assignable).to be(true)
  end

  it "rejects a submitted type outside the allowlist when the id is blank" do
    note = Note.new(notable_type: "User", notable_id: nil)
    attrs = { "notable_type" => "Tag", "notable_id" => "" }.with_indifferent_access

    host = polymorphic_host
    field = notable_polymorphic_field
    host.define_singleton_method(:writable_form_fields) { [field] }

    allowed = host.send(:polymorphic_types_allowed?, note, attrs)

    expect(allowed).to be(false)
    expect(note.errors[:notable]).to include("is not available")
  end

  def polymorphic_host
    host = Class.new { include IronAdmin::Concerns::AssignableReferences }.new
    host.define_singleton_method(:present_attr?) { |attrs, key| attrs[key].present? }
    host.define_singleton_method(:not_assignable_message) { "is not available" }
    host.define_singleton_method(:helpers) { assignable_admin_users }
    host
  end

  def notable_polymorphic_field
    Struct.new(:name, :type, :options).new(
      :notable,
      :polymorphic_belongs_to,
      { type_column: :notable_type, id_column: :notable_id, types: [User] }
    )
  end

  def assignable_admin_users
    helper = Object.new
    helper.define_singleton_method(:assignable_records) { |model| model.where(role: "admin") }
    helper
  end
end
