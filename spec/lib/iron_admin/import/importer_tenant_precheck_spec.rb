# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Import::Importer do
  describe "non-transactional tenant pre-check" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = Post

        def self.name = "PrecheckedPostImportResource"
        def self.resource_name = "prechecked_post_imports"

        imports :csv
        import_fields :id, :title, :published

        def self.import_upsert_key_names = [:id]
      end
    end

    before do
      IronAdmin.configure do |config|
        config.tenant_scope { |scope| scope.model == Post ? scope.where(published: true) : scope }
      end
      adapter = resource.adapter
      allow(resource).to receive(:adapter).and_return(adapter)
      allow(adapter).to receive(:supports_transactions?).and_return(false)
      allow(adapter).to receive(:scope_match) { |_scope, candidate| candidate.published ? :inside : :outside }
      allow(adapter).to receive(:preview) { |record, attrs| record.dup.tap { |copy| copy.assign_attributes(attrs) } }
    end

    it "imports an update that changes another field while the csv carries a different tenant value" do
      post = Post.create!(title: "Old Title", published: true)
      csv = StringIO.new("Id,Title,Published\n#{post.id},New Title,false\n")

      result = described_class.new(resource, file: csv, format: :csv).execute!

      expect([result.updated_count, result.failed_count]).to eq([1, 0])
      expect(post.reload.title).to eq("New Title")
      expect(post.published).to be(true)
    end

    it "rejects a create whose candidate is outside the tenant and saves nothing" do
      allow(resource.adapter).to receive(:build_in) { Post.new(title: "Outside Title", published: false) }
      csv = StringIO.new("Id,Title,Published\n,Outside Title,false\n")

      result = described_class.new(resource, file: csv, format: :csv).execute!

      expect(result.errors.map(&:message)).to eq(
        ["This row would put the record outside your tenant."]
      )
      expect([result.created_count, result.updated_count, result.failed_count]).to eq([0, 0, 1])
      expect(Post.where(title: "Outside Title").count).to eq(0)
    end

    it "imports a create whose candidate is inside the tenant" do
      csv = StringIO.new("Id,Title,Published\n,Inside Title,true\n")

      result = described_class.new(resource, file: csv, format: :csv).execute!

      expect(result.errors.map(&:message)).to be_empty
      expect([result.created_count, result.updated_count, result.failed_count]).to eq([1, 0, 0])
      expect(Post.where(title: "Inside Title", published: true).count).to eq(1)
    end

    it "rejects an update when the preview is missing and leaves the record unchanged" do
      post = Post.create!(title: "Keep Title", published: true)
      allow(resource.adapter).to receive(:preview).and_return(nil)
      csv = StringIO.new("Id,Title,Published\n#{post.id},Changed Title,true\n")

      result = described_class.new(resource, file: csv, format: :csv).execute!

      expect(result.errors.map(&:message)).to eq(
        ["This row cannot be checked against your tenant, so it was not imported."]
      )
      expect([result.created_count, result.updated_count, result.failed_count]).to eq([0, 0, 1])
      expect([post.reload.title, post.published]).to eq(["Keep Title", true])
    end

    it "rejects an update when scope match is unknown and leaves the record unchanged" do
      post = Post.create!(title: "Stable Title", published: true)
      allow(resource.adapter).to receive(:scope_match).and_return(:unknown)
      csv = StringIO.new("Id,Title,Published\n#{post.id},Other Title,true\n")

      result = described_class.new(resource, file: csv, format: :csv).execute!

      expect(result.errors.map(&:message)).to eq(
        ["This row cannot be checked against your tenant, so it was not imported."]
      )
      expect([result.created_count, result.updated_count, result.failed_count]).to eq([0, 0, 1])
      expect([post.reload.title, post.published]).to eq(["Stable Title", true])
    end
  end
end
