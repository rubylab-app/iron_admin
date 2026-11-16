# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Concerns::NestedPermittable do
  subject(:permit_list) { host.permit_list(nested) }

  let(:host) do
    Class.new do
      include IronAdmin::Concerns::NestedPermittable

      def iron_admin_current_user
        nil
      end

      def permit_list(nested)
        build_nested_permit_list(nested)
      end
    end.new
  end

  let(:nested) do
    IronAdmin::NestedAssociation.new(
      name: :licenses,
      kind: :has_many,
      reflection: nil,
      fields: [
        IronAdmin::Field.new(:license_key, type: :text),
        IronAdmin::Field.new(:max_devices, type: :number, visible: false),
      ],
      allow_destroy: true,
      position_field: nil
    )
  end

  it "permits visible fields and drops fields concealed from the current user" do
    expect(permit_list).to include(:license_key, :id, :_destroy)
    expect(permit_list).not_to include(:max_devices)
  end
end
