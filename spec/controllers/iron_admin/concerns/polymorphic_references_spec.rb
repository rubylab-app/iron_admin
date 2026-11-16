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
end
