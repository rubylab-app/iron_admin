require "rails_helper"

RSpec.describe "IronAdmin Soft Delete Support" do
  # Create a temporary table with deleted_at column for testing
  before(:all) do
    ActiveRecord::Base.connection.create_table :articles, force: true do |t|
      t.string :title
      t.text :content
      t.datetime :deleted_at
      t.timestamps
    end

    # Define the Article model dynamically
    Object.const_set(:Article, Class.new(ApplicationRecord) do
      # Simulate paranoia/discard default scope
      default_scope { where(deleted_at: nil) }
    end)
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :articles, if_exists: true
    Object.send(:remove_const, :Article) if defined?(Article)
  end

  # Create ArticleResource for testing
  let(:article_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = Article

      def self.name
        "ArticleResource"
      end

      def self.resource_name
        "articles"
      end
    end
  end

  # Create a resource without deleted_at for comparison
  let(:regular_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name
        "RegularUserResource"
      end

      def self.resource_name
        "regular_users"
      end
    end
  end

  describe ".soft_delete?" do
    it "returns true when model has deleted_at column" do
      expect(article_resource.soft_delete?).to be(true)
    end

    it "returns false when model does not have deleted_at column" do
      expect(regular_resource.soft_delete?).to be(false)
    end
  end

  describe ".soft_delete_column" do
    it "returns 'deleted_at' as the column name" do
      expect(article_resource.soft_delete_column).to eq("deleted_at")
    end
  end

  describe "auto-registered scopes for soft delete models" do
    before do
      IronAdmin::ResourceRegistry.register(article_resource)
    end

    describe "with_deleted scope" do
      it "is automatically registered for soft delete models" do
        scopes = article_resource.all_scopes
        with_deleted_scope = scopes.find { |s| s[:name] == :with_deleted }
        expect(with_deleted_scope).to be_present
      end

      it "shows all records including deleted ones" do
        # Create some articles
        active_article = Article.create!(title: "Active", content: "Content")
        deleted_article = Article.unscoped.create!(title: "Deleted", content: "Content", deleted_at: Time.current)

        with_deleted_scope = article_resource.all_scopes.find { |s| s[:name] == :with_deleted }
        scope_result = Article.merge(with_deleted_scope[:scope])

        expect(scope_result).to include(active_article)
        expect(scope_result).to include(deleted_article)
      end
    end

    describe "only_deleted scope" do
      it "is automatically registered for soft delete models" do
        scopes = article_resource.all_scopes
        only_deleted_scope = scopes.find { |s| s[:name] == :only_deleted }
        expect(only_deleted_scope).to be_present
      end

      it "shows only deleted records" do
        # Create some articles
        active_article = Article.create!(title: "Active", content: "Content")
        deleted_article = Article.unscoped.create!(title: "Deleted", content: "Content", deleted_at: Time.current)

        only_deleted_scope = article_resource.all_scopes.find { |s| s[:name] == :only_deleted }
        scope_result = Article.unscoped.merge(only_deleted_scope[:scope])

        expect(scope_result).not_to include(active_article)
        expect(scope_result).to include(deleted_article)
      end
    end
  end

  describe "scope ordering" do
    it "places user-defined scopes before soft delete scopes" do
      resource_with_scopes = Class.new(IronAdmin::Resource) do
        self.model_class_override = Article

        def self.name
          "ScopedArticleResource"
        end

        def self.resource_name
          "scoped_articles"
        end

        scope :recent, -> { where("created_at > ?", 1.week.ago) }
        scope :featured, -> { where(title: "Featured") }
      end

      IronAdmin::ResourceRegistry.register(resource_with_scopes)
      scope_names = resource_with_scopes.all_scopes.pluck(:name)

      expect(scope_names).to eq(%i[recent featured with_deleted only_deleted])
    end
  end

  describe "auto-registered restore action for soft delete models" do
    before do
      IronAdmin::ResourceRegistry.register(article_resource)
    end

    it "is automatically registered for soft delete models" do
      actions = article_resource.defined_actions
      restore_action = actions.find { |a| a[:name] == :restore }
      expect(restore_action).to be_present
    end

    it "has the arrow-path icon" do
      actions = article_resource.defined_actions
      restore_action = actions.find { |a| a[:name] == :restore }
      expect(restore_action[:icon]).to eq("arrow-path")
    end

    it "clears deleted_at when executed" do
      deleted_article = Article.unscoped.create!(title: "Deleted", content: "Content", deleted_at: Time.current)
      expect(deleted_article.deleted_at).to be_present

      actions = article_resource.defined_actions
      restore_action = actions.find { |a| a[:name] == :restore }
      restore_action[:block].call(deleted_article)

      expect(deleted_article.reload.deleted_at).to be_nil
    end

    it "is idempotent: calling register_soft_delete_features multiple times does not duplicate the restore action" do
      article_resource.register_soft_delete_features
      article_resource.register_soft_delete_features

      restore_actions = article_resource.defined_actions.select { |a| a[:name] == :restore }
      expect(restore_actions.size).to eq(1)
    end
  end

  describe "when database is unavailable" do
    let(:unavailable_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = Article

        def self.name
          "UnavailableResource"
        end

        def self.resource_name
          "unavailable"
        end
      end
    end

    it "does not raise ActiveRecord::NoDatabaseError" do
      allow(Article).to receive(:column_names).and_raise(ActiveRecord::NoDatabaseError)

      expect { unavailable_resource.register_soft_delete_features }.not_to raise_error
    end

    it "does not raise ActiveRecord::StatementInvalid" do
      allow(Article).to receive(:column_names).and_raise(ActiveRecord::StatementInvalid)

      expect { unavailable_resource.register_soft_delete_features }.not_to raise_error
    end

    it "does not raise ActiveRecord::ConnectionNotEstablished (transient outage)" do
      allow(Article).to receive(:column_names).and_raise(ActiveRecord::ConnectionNotEstablished)

      expect { unavailable_resource.register_soft_delete_features }.not_to raise_error
    end

    it "logs a warning when soft-delete features are skipped" do
      allow(Article).to receive(:column_names).and_raise(ActiveRecord::ConnectionNotEstablished, "boom")
      allow(Rails.logger).to receive(:warn)

      unavailable_resource.register_soft_delete_features

      expect(Rails.logger).to have_received(:warn)
        .with(/Skipping soft-delete features for UnavailableResource.*ActiveRecord::ConnectionNotEstablished.*boom/)
    end

    it "does not register any scopes or actions" do
      allow(Article).to receive(:column_names).and_raise(ActiveRecord::NoDatabaseError)

      unavailable_resource.register_soft_delete_features

      expect(unavailable_resource.all_scopes).to be_empty
      expect(unavailable_resource.defined_actions).to be_empty
    end
  end

  describe "non-soft-delete models" do
    before do
      IronAdmin::ResourceRegistry.register(regular_resource)
    end

    it "does not register with_deleted scope" do
      scopes = regular_resource.defined_scopes
      with_deleted_scope = scopes.find { |s| s[:name] == :with_deleted }
      expect(with_deleted_scope).to be_nil
    end

    it "does not register only_deleted scope" do
      scopes = regular_resource.defined_scopes
      only_deleted_scope = scopes.find { |s| s[:name] == :only_deleted }
      expect(only_deleted_scope).to be_nil
    end

    it "does not register restore action" do
      actions = regular_resource.defined_actions
      restore_action = actions.find { |a| a[:name] == :restore }
      expect(restore_action).to be_nil
    end
  end
end
