# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::FieldInferrer do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::NoteResource)
  end

  describe "polymorphic detection" do
    it "detects polymorphic belongs_to association" do
      fields = described_class.call(Note)
      notable_field = fields.find { |f| f.name == :notable }

      expect(notable_field).to be_present
      expect(notable_field.type).to eq(:polymorphic_belongs_to)
    end

    it "stores type_column and id_column in options" do
      fields = described_class.call(Note)
      notable_field = fields.find { |f| f.name == :notable }

      expect(notable_field.options[:type_column]).to eq(:notable_type)
      expect(notable_field.options[:id_column]).to eq(:notable_id)
    end

    it "does not create separate fields for type and id columns" do
      fields = described_class.call(Note)
      field_names = fields.map(&:name)

      expect(field_names).not_to include(:notable_type)
      expect(field_names).not_to include(:notable_id)
    end
  end

  describe "Resource DSL" do
    it "stores polymorphic: true in association config" do
      config = IronAdmin::Resources::NoteResource.defined_associations[:notable]
      expect(config[:polymorphic]).to be true
    end

    it "stores types list" do
      config = IronAdmin::Resources::NoteResource.defined_associations[:notable]
      expect(config[:types]).to eq([User, License])
    end
  end

  describe "resolved_fields" do
    it "includes polymorphic field with types from DSL" do
      fields = IronAdmin::Resources::NoteResource.resolved_fields
      notable_field = fields.find { |f| f.name == :notable }

      expect(notable_field.type).to eq(:polymorphic_belongs_to)
      expect(notable_field.options[:types]).to eq([User, License])
    end
  end

  describe "polymorphic types auto-inference" do
    it "asks the adapter for polymorphic inverse classes" do
      adapter = IronAdmin::Adapters::ActiveRecord.new(Note)
      allow(adapter).to receive(:polymorphic_inverse_classes).with(:notable).and_return([User])

      fields = described_class.call(adapter)
      notable_field = fields.find { |f| f.name == :notable }

      expect(notable_field.options[:types]).to eq([User])
    end

    it "infers types from `has_many :as` declarations across ApplicationRecord descendants" do
      fields = described_class.call(Note)
      notable_field = fields.find { |f| f.name == :notable }

      expect(notable_field.options[:types]).to include(User, License)
    end

    it "eager-loads model paths before scanning descendants in lazy-load environments" do
      calls = []
      paths = ActiveSupport::Dependencies.autoload_paths

      allow(Rails.application.config).to receive(:eager_load_paths).and_return(paths)
      allow(Rails.autoloaders.main).to receive(:eager_load_dir) { |path| calls << path }

      described_class.call(Note)

      expect(calls).to include(*paths.select { |path| path.end_with?("/app/models") })
    end

    it "excludes abstract classes" do
      fields = described_class.call(Note)
      notable_field = fields.find { |f| f.name == :notable }

      expect(notable_field.options[:types]).not_to include(ApplicationRecord)
    end

    it "returns an empty Array when no model declares the inverse `has_many :as`" do
      stub_const("OrphanModel", Class.new(ApplicationRecord) do
        self.table_name = "notes"
        belongs_to :ghost, polymorphic: true, optional: true
      end)

      fields = described_class.call(OrphanModel)
      ghost_field = fields.find { |f| f.name == :ghost }

      expect(ghost_field.options[:types]).to eq([])
    end

    it "also picks up `has_one :as` declarations" do
      stub_const("HasOneTarget", Class.new(ApplicationRecord) do
        self.table_name = "users"
        has_one :note, as: :notable, class_name: "::Note"
      end)

      fields = described_class.call(Note)
      notable_field = fields.find { |f| f.name == :notable }

      expect(notable_field.options[:types]).to include(HasOneTarget)
    end

    it "excludes STI subclasses (Rails stores the base class name in the *_type column)" do
      sti_base = Class.new(ApplicationRecord) do
        self.table_name = "users"
        has_many :notes, as: :notable
      end
      stub_const("StiBase", sti_base)
      stub_const("StiChild", Class.new(sti_base))

      fields = described_class.call(Note)
      notable_field = fields.find { |f| f.name == :notable }

      expect(notable_field.options[:types]).to include(StiBase)
      expect(notable_field.options[:types]).not_to include(StiChild)
    end
  end
end
