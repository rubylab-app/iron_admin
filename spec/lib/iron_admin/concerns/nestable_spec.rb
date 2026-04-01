# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Concerns::Nestable do
  describe "AssociationDsl" do
    describe ".has_many" do
      context "with nested options" do
        let(:resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.name
              "NestableDslTestResource"
            end

            has_many :licenses, nested: true, allow_destroy: false, position_field: :max_devices, fields: %i[license_key]
          end
        end

        it "stores nested flag" do
          expect(resource.defined_associations[:licenses][:nested]).to be(true)
        end

        it "stores allow_destroy" do
          expect(resource.defined_associations[:licenses][:allow_destroy]).to be(false)
        end

        it "stores position_field as symbol" do
          expect(resource.defined_associations[:licenses][:position_field]).to eq(:max_devices)
        end

        it "stores fields" do
          expect(resource.defined_associations[:licenses][:fields]).to eq(%i[license_key])
        end
      end

      context "without nested options" do
        let(:resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.name
              "NestablePlainTestResource"
            end

            has_many :licenses
          end
        end

        it "defaults nested to false" do
          expect(resource.defined_associations[:licenses][:nested]).to be(false)
        end

        it "defaults allow_destroy to true" do
          expect(resource.defined_associations[:licenses][:allow_destroy]).to be(true)
        end

        it "defaults position_field to nil" do
          expect(resource.defined_associations[:licenses][:position_field]).to be_nil
        end
      end
    end

    describe ".has_one" do
      context "with nested options" do
        let(:resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.name
              "NestableHasOneDslResource"
            end

            has_one :profile, nested: true, allow_destroy: false, fields: %i[bio]
          end
        end

        it "stores kind as :has_one" do
          expect(resource.defined_associations[:profile][:kind]).to eq(:has_one)
        end

        it "stores nested flag" do
          expect(resource.defined_associations[:profile][:nested]).to be(true)
        end

        it "stores fields" do
          expect(resource.defined_associations[:profile][:fields]).to eq(%i[bio])
        end
      end
    end
  end

  describe "NestedReader" do
    describe ".nested_associations" do
      context "with mixed nested and non-nested associations" do
        let(:resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.name
              "NestableReaderMixedResource"
            end

            has_many :licenses, nested: true
            has_one :profile
          end
        end

        it "returns only associations with nested: true" do
          expect(resource.nested_associations.map(&:name)).to eq([:licenses])
        end
      end

      context "when model lacks accepts_nested_attributes_for" do
        let(:resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.name
              "NestableReaderBadResource"
            end

            has_one :profile, nested: true
          end
        end

        it "raises ArgumentError" do
          expect { resource.nested_associations }.to raise_error(ArgumentError, /accepts_nested_attributes_for :profile/)
        end
      end

      context "with explicit fields" do
        let(:resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.name
              "NestableReaderExplicitResource"
            end

            has_many :licenses, nested: true, fields: %i[license_key status]
          end
        end

        it "only includes specified fields" do
          field_names = resource.nested_associations.first.fields.map(&:name)
          expect(field_names).to eq(%i[license_key status])
        end
      end

      context "with auto-inferred fields" do
        let(:resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.name
              "NestableReaderAutoResource"
            end

            has_many :licenses, nested: true
          end
        end

        it "excludes id" do
          field_names = resource.nested_associations.first.fields.map(&:name)
          expect(field_names).not_to include(:id)
        end

        it "excludes timestamps" do
          field_names = resource.nested_associations.first.fields.map(&:name)
          expect(field_names).not_to include(:created_at, :updated_at)
        end

        it "excludes foreign key" do
          field_names = resource.nested_associations.first.fields.map(&:name)
          expect(field_names).not_to include(:user_id)
        end

        it "includes data columns" do
          field_names = resource.nested_associations.first.fields.map(&:name)
          expect(field_names).to include(:license_key, :status)
        end
      end
    end
  end
end
