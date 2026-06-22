require "rails_helper"

RSpec.describe "IronAdmin Soft Delete Integration", type: :request do
  # Create a temporary table with deleted_at column for testing
  # Uses a unique table name to avoid collisions with the real posts table
  before(:all) do
    ActiveRecord::Base.connection.create_table :soft_delete_posts, force: true do |t|
      t.string :title
      t.text :body
      t.datetime :deleted_at
      t.timestamps
    end

    # Define the SoftDeletePost model dynamically
    Object.const_set(:SoftDeletePost, Class.new(ApplicationRecord) do
      self.table_name = "soft_delete_posts"
      # Simulate paranoia/discard default scope
      default_scope { where(deleted_at: nil) }
    end)
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :soft_delete_posts, if_exists: true
    Object.send(:remove_const, :SoftDeletePost) if defined?(SoftDeletePost)
  end

  # Create SoftDeletePostResource for testing
  let(:post_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = SoftDeletePost

      def self.name
        "SoftDeletePostResource"
      end

      def self.resource_name
        "soft_delete_posts"
      end
    end
  end

  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(post_resource)
  end

  describe "GET /:resource_name with soft delete scopes" do
    let!(:active_post) { SoftDeletePost.create!(title: "Active Post", body: "Content") }
    let!(:deleted_post) { SoftDeletePost.unscoped.create!(title: "Deleted Post", body: "Content", deleted_at: Time.current) }

    it "shows only non-deleted records by default" do
      get iron_admin.resources_path("soft_delete_posts"), as: :html
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Active Post")
      expect(response.body).not_to include("Deleted Post")
    end

    it "shows all records with with_deleted scope" do
      get iron_admin.resources_path("soft_delete_posts"), params: { scope: "with_deleted" }, as: :html
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Active Post")
      expect(response.body).to include("Deleted Post")
    end

    it "shows only deleted records with only_deleted scope" do
      get iron_admin.resources_path("soft_delete_posts"), params: { scope: "only_deleted" }, as: :html
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Active Post")
      expect(response.body).to include("Deleted Post")
    end
  end

  describe "POST /:resource_name/:id/actions/restore" do
    let!(:deleted_post) { SoftDeletePost.unscoped.create!(title: "Deleted Post", body: "Content", deleted_at: Time.current) }

    it "restores a soft deleted record" do
      expect(deleted_post.deleted_at).to be_present

      post iron_admin.resource_action_path("soft_delete_posts", deleted_post.id, "restore"), as: :html

      expect(deleted_post.reload.deleted_at).to be_nil
    end

    it "redirects to the show page after restore" do
      post iron_admin.resource_action_path("soft_delete_posts", deleted_post.id, "restore"), as: :html
      expect(response).to redirect_to(iron_admin.resource_path("soft_delete_posts", deleted_post))
    end
  end

  context "when the action condition is false on direct restore routes" do
    let!(:active_post) { SoftDeletePost.create!(title: "Active Post", body: "Content") }

    it "forbids the restore action form" do
      get iron_admin.resource_action_form_path("soft_delete_posts", active_post.id, "restore"), as: :html

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids executing restore" do
      post iron_admin.resource_action_path("soft_delete_posts", active_post.id, "restore"), as: :html

      expect(response).to have_http_status(:forbidden)
      expect(active_post.reload.deleted_at).to be_nil
    end
  end
end
