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

  describe "show of an active record" do
    let!(:active_post) { SoftDeletePost.create!(title: "Active Post", body: "Content") }

    it "links to the edit page" do
      get iron_admin.resource_path("soft_delete_posts", active_post), as: :html

      edit_path = iron_admin.edit_resource_path("soft_delete_posts", active_post)
      expect(response.parsed_body.css("a[href='#{edit_path}']")).not_to be_empty
    end
  end

  describe "show and update of a deleted record" do
    let!(:deleted_post) do
      SoftDeletePost.unscoped.create!(title: "Deleted Post", body: "Content", deleted_at: Time.current)
    end

    it "shows the deleted record" do
      get iron_admin.resource_path("soft_delete_posts", deleted_post), as: :html

      expect(response).to have_http_status(:ok)
    end

    it "does not link to the edit page, which cannot load the deleted record" do
      get iron_admin.resource_path("soft_delete_posts", deleted_post), as: :html

      edit_path = iron_admin.edit_resource_path("soft_delete_posts", deleted_post)
      expect(response.parsed_body.css("a[href='#{edit_path}']")).to be_empty
    end

    it "keeps the delete button" do
      get iron_admin.resource_path("soft_delete_posts", deleted_post), as: :html

      expect(response.parsed_body.css("form[action='#{iron_admin.resource_path("soft_delete_posts", deleted_post)}']")).not_to be_empty
    end

    it "returns not found when updating the deleted record" do
      patch iron_admin.resource_path("soft_delete_posts", deleted_post),
            params: { record: { title: "Changed", body: "Content" } },
            as: :html

      expect(response).to have_http_status(:not_found)
    end

    it "destroys a deleted record" do
      delete iron_admin.resource_path("soft_delete_posts", deleted_post), as: :html

      expect(SoftDeletePost.unscoped.exists?(deleted_post.id)).to be(false)
    end
  end

  describe "member actions on the show page" do
    let(:post_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = SoftDeletePost

        def self.name
          "SoftDeletePostResource"
        end

        def self.resource_name
          "soft_delete_posts"
        end

        action :publish do |post|
          post.update!(title: "Published")
        end

        action :retitle, form_fields: [action_field(:title, type: :text)] do |post, params|
          post.update!(title: params[:title])
        end
      end
    end

    def action_buttons(record, action_name)
      response.parsed_body.css("form[action='#{iron_admin.resource_action_path("soft_delete_posts", record, action_name)}']")
    end

    def form_links(record, action_name)
      response.parsed_body.css("a[href='#{iron_admin.resource_action_form_path("soft_delete_posts", record, action_name)}']")
    end

    context "with a deleted record that the default scope hides" do
      let!(:deleted_post) do
        SoftDeletePost.unscoped.create!(title: "Deleted Post", body: "Content", deleted_at: Time.current)
      end

      before { get iron_admin.resource_path("soft_delete_posts", deleted_post), as: :html }

      it "offers the restore action" do
        expect(action_buttons(deleted_post, :restore)).not_to be_empty
      end

      it "does not offer actions that cannot load the deleted record" do
        expect(action_buttons(deleted_post, :publish)).to be_empty
      end

      it "does not link the form of an action that cannot load the deleted record" do
        expect(form_links(deleted_post, :retitle)).to be_empty
      end

      it "returns not found for that form, as executing the action does" do
        get iron_admin.resource_action_form_path("soft_delete_posts", deleted_post, "retitle"), as: :html
        expect(response).to have_http_status(:not_found)
      end

      it "loads the deleted record in the restore form" do
        get iron_admin.resource_action_form_path("soft_delete_posts", deleted_post, "restore"), as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "with an active record" do
      let!(:active_post) { SoftDeletePost.create!(title: "Active Post", body: "Content") }

      before { get iron_admin.resource_path("soft_delete_posts", active_post), as: :html }

      it "offers its custom actions" do
        expect(action_buttons(active_post, :publish)).not_to be_empty
      end

      it "links the form of its actions with form fields" do
        expect(form_links(active_post, :retitle)).not_to be_empty
      end

      it "does not offer restore, whose condition is false" do
        expect(action_buttons(active_post, :restore)).to be_empty
      end
    end
  end

  # discard (with discard_column = :deleted_at) and hand-rolled soft delete
  # leave deleted rows visible, so edit and update can still load them.
  describe "show of a deleted record on a model without a default scope" do
    before(:all) do
      ActiveRecord::Base.connection.create_table :plain_soft_delete_posts, force: true do |t|
        t.string :title
        t.datetime :deleted_at
        t.timestamps
      end

      Object.const_set(:PlainSoftDeletePost, Class.new(ApplicationRecord) do
        self.table_name = "plain_soft_delete_posts"
      end)
    end

    after(:all) do
      ActiveRecord::Base.connection.drop_table :plain_soft_delete_posts, if_exists: true
      Object.send(:remove_const, :PlainSoftDeletePost) if defined?(PlainSoftDeletePost)
    end

    let(:plain_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = PlainSoftDeletePost

        def self.name
          "PlainSoftDeletePostResource"
        end

        def self.resource_name
          "plain_soft_delete_posts"
        end

        action :publish do |post|
          post.update!(title: "Published")
        end
      end
    end

    let!(:deleted_post) { PlainSoftDeletePost.create!(title: "Deleted Post", deleted_at: Time.current) }

    before { IronAdmin::ResourceRegistry.register(plain_resource) }

    it "links to the edit page, which can still load the deleted record" do
      get iron_admin.resource_path("plain_soft_delete_posts", deleted_post), as: :html

      edit_path = iron_admin.edit_resource_path("plain_soft_delete_posts", deleted_post)
      expect(response.parsed_body.css("a[href='#{edit_path}']")).not_to be_empty
    end

    it "offers custom actions, which can still load the deleted record" do
      get iron_admin.resource_path("plain_soft_delete_posts", deleted_post), as: :html

      action_path = iron_admin.resource_action_path("plain_soft_delete_posts", deleted_post, :publish)
      expect(response.parsed_body.css("form[action='#{action_path}']")).not_to be_empty
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

    it "shows the success notice after restore" do
      post iron_admin.resource_action_path("soft_delete_posts", deleted_post.id, "restore"), as: :html
      expect(flash[:notice]).to eq("Action completed")
    end

    context "when the restored record fails validation" do
      subject(:restore) { post iron_admin.resource_action_path("validated_soft_delete_posts", invalid_post.id, "restore") }

      let(:validated_model) do
        Class.new(ApplicationRecord) do
          self.table_name = "soft_delete_posts"
          default_scope { where(deleted_at: nil) }
          validates :body, presence: true

          def self.name
            "ValidatedSoftDeletePost"
          end
        end
      end
      let(:validated_resource) do
        model = validated_model
        Class.new(IronAdmin::Resource) do
          self.model_class_override = model

          def self.name
            "ValidatedSoftDeletePostResource"
          end

          def self.resource_name
            "validated_soft_delete_posts"
          end
        end
      end
      let!(:invalid_post) { SoftDeletePost.unscoped.create!(title: "Invalid Post", body: "", deleted_at: Time.current) }

      before do
        IronAdmin.configure { |config| config.audit_enabled = true }
        IronAdmin::ResourceRegistry.register(validated_resource)
      end

      it "keeps the record deleted" do
        restore
        expect(invalid_post.reload.deleted_at).to be_present
      end

      it "shows the validation errors" do
        restore
        expect(flash[:alert]).to eq("Action was not completed: Body can't be blank")
      end

      it "does not show the success notice" do
        restore
        expect(flash[:notice]).to be_nil
      end

      it "redirects to the show page" do
        restore
        expect(response).to redirect_to(iron_admin.resource_path("validated_soft_delete_posts", invalid_post))
      end

      it "logs nothing" do
        restore
        expect(IronAdmin::AuditLog.entries).to be_empty
      end
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

  describe "scope counts" do
    let(:counted_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = SoftDeletePost

        def self.name = "CountedSoftDeletePostResource"
        def self.resource_name = "counted_soft_delete_posts"

        scope_counts true
      end
    end
    let!(:live_post) { SoftDeletePost.create!(title: "Counted Live", body: "Content") }
    let!(:deleted_post) do
      SoftDeletePost.unscoped.create!(title: "Counted Gone", body: "Content", deleted_at: Time.current)
    end

    before { IronAdmin::ResourceRegistry.register(counted_resource) }

    def soft_delete_tab(name)
      label = name.to_s.humanize
      pattern = /\A#{Regexp.escape(label)}(?: \(\d+\))?\z/
      response.parsed_body.css("a").find { |link| link.text.squish.match?(pattern) }&.text&.squish
    end

    it "counts live and deleted rows on with_deleted" do
      get iron_admin.resources_path("counted_soft_delete_posts"), as: :html

      expect(soft_delete_tab("with_deleted")).to eq("With deleted (2)")
    end

    it "counts only deleted rows on only_deleted" do
      get iron_admin.resources_path("counted_soft_delete_posts"), as: :html

      expect(soft_delete_tab("only_deleted")).to eq("Only deleted (1)")
    end

    it "keeps the with_deleted count while only_deleted is selected" do
      get iron_admin.resources_path("counted_soft_delete_posts"), params: { scope: "only_deleted" }, as: :html

      expect(soft_delete_tab("with_deleted")).to eq("With deleted (2)")
    end
  end
end
