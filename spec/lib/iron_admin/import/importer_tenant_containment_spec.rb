# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Import::Importer do
  describe "tenant containment" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = Post

        def self.name = "ContainedPostImportResource"
        def self.resource_name = "contained_post_imports"

        imports :csv
        import_fields :title, :published
      end
    end

    before do
      IronAdmin.configure do |config|
        # An IN list: scope_attributes cannot stamp it, so only the post-write check keeps rows inside.
        config.tenant_scope { |scope| scope.model == Post ? scope.where(title: ["Inside Post", "Other Post"]) : scope }
      end
    end

    it "imports the in-tenant row and rolls the outsider row back" do
      csv = StringIO.new("Title,Published\nInside Post,true\nOutside Post,false\n")

      result = described_class.new(resource, file: csv, format: :csv).execute!

      expect([result.created_count, result.failed_count]).to eq([1, 1])
      expect(Post.where(title: "Inside Post")).to exist
      expect(Post.where(title: "Outside Post")).not_to exist
    end
  end
end
