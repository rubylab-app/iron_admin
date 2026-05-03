# frozen_string_literal: true

require "rails_helper"
require "rails/generators"
require "generators/iron_admin/install_audit/install_audit_generator"

RSpec.describe IronAdmin::Generators::InstallAuditGenerator, type: :generator do
  describe "generator class" do
    it "is defined" do
      expect(described_class).to be_a(Class)
    end

    it "inherits from Rails::Generators::Base" do
      expect(described_class.superclass).to eq(Rails::Generators::Base)
    end

    it "does not include Rails::Generators::Migration" do
      # We deliberately don't use `Rails::Generators::Migration` because
      # `migration_template` opens an AR connection (to look up the
      # current migration version), which would crash on a fresh
      # machine with no DB yet.
      expect(described_class.included_modules).not_to include(Rails::Generators::Migration)
    end

    it "has a source_root" do
      expect(described_class.source_root).to be_a(String)
      expect(File.directory?(described_class.source_root)).to be true
    end
  end

  describe "running the generator" do
    let(:destination) { File.expand_path("../../tmp_audit", __dir__) }

    before do
      FileUtils.rm_rf(destination)
      FileUtils.mkdir_p(File.join(destination, "db/migrate"))
    end

    after do
      FileUtils.rm_rf(destination)
    end

    def run_generator(args = [])
      described_class.start(args, destination_root: destination)
    end

    it "writes a timestamped migration file with the right name suffix" do
      run_generator
      files = Dir.glob(File.join(destination, "db/migrate", "*_create_iron_admin_audit_entries.rb"))
      expect(files.size).to eq(1)
      expect(File.basename(files.first)).to match(/\A\d{14}_create_iron_admin_audit_entries\.rb\z/)
    end

    it "writes the migration without opening an AR connection" do
      # If `migration_template` were used, this would call into
      # ActiveRecord::Base.connection.schema_migration etc. We assert
      # the generator runs cleanly without any AR interaction.
      allow(ActiveRecord::Base).to receive(:connection)
      expect { run_generator }.not_to raise_error
      expect(ActiveRecord::Base).not_to have_received(:connection)
    end

    it "skips when an audit migration already exists" do
      # Stub Time.now so the second `next_migration_number`-equivalent
      # would naturally produce a different timestamp — but the skip
      # branch should fire before any timestamp computation matters.
      # Using a stub keeps the spec sub-second instead of relying on
      # `sleep` (slow + flaky on loaded CI).
      times = [Time.utc(2026, 5, 3, 12, 0, 0), Time.utc(2026, 5, 3, 12, 0, 1)]
      allow(Time).to receive(:now).and_return(*times)

      # First run creates the migration
      run_generator

      expect { run_generator }
        .to output(/skip.*create_iron_admin_audit_entries.*already exists/m).to_stdout

      # Still only one migration file
      files = Dir.glob(File.join(destination, "db/migrate", "*_create_iron_admin_audit_entries.rb"))
      expect(files.size).to eq(1)
    end
  end

  describe "migration template" do
    let(:template_path) do
      File.join(described_class.source_root, "create_iron_admin_audit_entries.rb.tt")
    end

    it "exists" do
      expect(File.exist?(template_path)).to be true
    end

    it "creates iron_admin_audit_entries table" do
      content = File.read(template_path)
      expect(content).to include("create_table :iron_admin_audit_entries")
    end

    it "includes required columns" do
      content = File.read(template_path)
      expect(content).to include("t.string :action")
      expect(content).to include("t.string :resource")
      expect(content).to include("t.integer :record_id")
      expect(content).to include("t.string :user_identifier")
      expect(content).to include("t.string :ip_address")
      expect(content).to include("t.text :record_changes")
    end

    it "includes timestamps" do
      content = File.read(template_path)
      expect(content).to include("t.timestamps")
    end

    it "includes indexes" do
      content = File.read(template_path)
      expect(content).to include("add_index :iron_admin_audit_entries, :resource")
      expect(content).to include("add_index :iron_admin_audit_entries, :action")
      expect(content).to include("add_index :iron_admin_audit_entries, :created_at")
    end
  end
end
