# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::ActionFormHelper, type: :helper do
  describe "#action_form_record_text" do
    subject(:text) { helper.action_form_record_text(resource_class, record) }

    let(:resource_class) { IronAdmin::Resources::UserResource }

    context "with a record that has a name" do
      let(:record) { create(:user, name: "Ana García", email: "ana@example.com") }

      it "names the record by model, id and name" do
        expect(text).to eq("Applies to User ##{record.id} (Ana García).")
      end
    end

    context "with a blank name" do
      let(:record) { build_stubbed(:user, name: "", email: "ana@example.com") }

      it "takes the next label, as display_record_label does" do
        expect(text).to eq("Applies to User ##{record.id} (ana@example.com).")
      end
    end

    context "with a record without a label" do
      let(:resource_class) { IronAdmin::Resources::LicenseResource }
      let(:record) { create(:license) }

      it "names the record by model and id" do
        expect(text).to eq("Applies to License ##{record.id}.")
      end
    end
  end
end
