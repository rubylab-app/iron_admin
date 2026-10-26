# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Concerns::Importable do
  describe ".importable_fields" do
    subject(:field_names) { resource.importable_fields.map(&:name) }

    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "ImportableFieldsUserResource"
        end

        imports :csv
      end
    end

    context "when import_fields lists fields out of column order" do
      before { resource.import_fields :preferences, :email, :name }

      it "follows the declared order" do
        expect(field_names).to eq(%i[preferences email name])
      end
    end

    context "when import_fields repeats a name" do
      before { resource.import_fields :email, :name, :email }

      it "lists the field once, at its first position" do
        expect(field_names).to eq(%i[email name])
      end
    end

    context "when import_fields lists a name with no field" do
      before { resource.import_fields :email, :nickname }

      it "leaves the name out" do
        expect(field_names).to eq(%i[email])
      end
    end

    context "when import_fields lists a field that cannot be imported" do
      before { resource.import_fields :email, :licenses }

      it "leaves the field out" do
        expect(field_names).to eq(%i[email])
      end
    end

    context "without import_fields" do
      it "lists every column except the id and timestamps in column order" do
        expect(field_names).to eq(%i[name email role active preferences])
      end
    end
  end
end
