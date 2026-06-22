# frozen_string_literal: true

require "rails_helper"

RSpec.describe "New Field Types", type: :request do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::DocumentResource)
  end

  describe "GET /:resource_name (index)" do
    it "renders documents index successfully" do
      create_list(:document, 3)
      get iron_admin.resources_path("documents"), as: :html

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /:resource_name/:id (show)" do
    it "renders document show with password field masked" do
      document = create(:document, password_hash: "hashed_secret")
      get iron_admin.resource_path("documents", document), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("\u2022" * 8)
      expect(response.body).not_to include("hashed_secret")
    end

    it "renders document show with file attachment" do
      document = create(:document)
      document.cover_image.attach(
        io: StringIO.new("image data"),
        filename: "cover.jpg",
        content_type: "image/jpeg"
      )

      get iron_admin.resource_path("documents", document), as: :html

      expect(response).to have_http_status(:ok)
    end

    it "renders document show with multiple file attachments" do
      document = create(:document)
      document.attachments.attach(
        io: StringIO.new("doc1"),
        filename: "report.pdf",
        content_type: "application/pdf"
      )

      get iron_admin.resource_path("documents", document), as: :html

      expect(response).to have_http_status(:ok)
    end

    it "renders document show with rich text content" do
      document = create(:document)
      document.update!(content: "Hello <strong>world</strong>")

      get iron_admin.resource_path("documents", document), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("prose")
    end
  end

  describe "GET /:resource_name/new" do
    it "renders form with password field" do
      get iron_admin.new_resource_path("documents"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('type="password"')
    end

    it "renders form with file upload field" do
      get iron_admin.new_resource_path("documents"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('type="file"')
    end

    it "renders form with rich text area" do
      get iron_admin.new_resource_path("documents"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("trix-editor")
    end

    it "renders form with multipart encoding" do
      get iron_admin.new_resource_path("documents"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("multipart/form-data")
    end
  end

  describe "POST /:resource_name (create)" do
    it "creates a document with basic fields" do
      expect do
        post iron_admin.resources_path("documents"),
             params: { record: { title: "Test Document", published: true } },
             as: :html
      end.to change(Document, :count).by(1)

      expect(response).to have_http_status(:redirect)
    end

    it "creates a document with file attachment" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("file content"),
        "application/pdf",
        true,
        original_filename: "test.pdf"
      )

      post iron_admin.resources_path("documents"),
           params: { record: { title: "With File", cover_image: file } },
           as: :html

      created_doc = Document.last
      expect(created_doc.cover_image).to be_attached
    end

    it "creates a document with rich text content" do
      post iron_admin.resources_path("documents"),
           params: { record: { title: "Rich Text Doc", content: "<p>Hello world</p>" } },
           as: :html

      created_doc = Document.last
      expect(created_doc.content.to_plain_text).to include("Hello world")
    end
  end

  describe "PATCH /:resource_name/:id (update)" do
    it "updates a document" do
      existing = create(:document, title: "Old Title")

      patch iron_admin.resource_path("documents", existing),
            params: { record: { title: "New Title" } },
            as: :html

      expect(existing.reload.title).to eq("New Title")
    end

    it "purges file attachment when checkbox is checked" do
      existing = create(:document)
      existing.cover_image.attach(
        io: StringIO.new("image"),
        filename: "photo.jpg",
        content_type: "image/jpeg"
      )

      expect(existing.cover_image).to be_attached

      patch iron_admin.resource_path("documents", existing),
            params: { record: { title: existing.title, cover_image_purge: "1" } },
            as: :html

      expect(existing.reload.cover_image).not_to be_attached
    end

    it "returns bad request for array-shaped record params before purging attachments" do
      existing = create(:document)

      patch iron_admin.resource_path("documents", existing),
            params: { record: ["bad"] },
            as: :html

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /:resource_name/:id (destroy)" do
    it "deletes a document" do
      existing = create(:document)

      expect do
        delete iron_admin.resource_path("documents", existing), as: :html
      end.to change(Document, :count).by(-1)
    end
  end

  describe "markdown field type" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::TagResource)
    end

    describe "GET /:resource_name/:id (show)" do
      it "renders markdown as HTML with Redcarpet" do
        post_record = create(:post, body_markdown: "# Hello\n\nThis is **bold** text.")
        get iron_admin.resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("prose")
        expect(response.body).to include("<h1>Hello</h1>")
        expect(response.body).to include("<strong>bold</strong>")
      end

      it "handles empty markdown gracefully" do
        post_record = create(:post, body_markdown: "")
        get iron_admin.resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
      end

      it "handles nil markdown gracefully" do
        post_record = create(:post, body_markdown: nil)
        get iron_admin.resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
      end

      it "renders fenced code blocks" do
        post_record = create(:post, body_markdown: "```ruby\nputs 'hello'\n```")
        get iron_admin.resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("<code")
      end
    end

    describe "GET /:resource_name/new" do
      it "renders form with markdown textarea" do
        get iron_admin.new_resource_path("posts"), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Write markdown here...")
        expect(response.body).to include("font-mono")
      end
    end

    describe "GET /:resource_name/:id/edit" do
      it "renders form with existing markdown content" do
        post_record = create(:post, body_markdown: "# Existing content")
        get iron_admin.edit_resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("# Existing content")
      end
    end

    describe "POST /:resource_name (create)" do
      it "creates record with markdown content" do
        post iron_admin.resources_path("posts"),
             params: { record: { title: "MD Post", body_markdown: "# New Post\n\nContent here." } },
             as: :html

        new_post = Post.last
        expect(new_post.body_markdown).to eq("# New Post\n\nContent here.")
      end
    end

    describe "PATCH /:resource_name/:id (update)" do
      it "updates markdown content" do
        post_record = create(:post, body_markdown: "# Old")

        patch iron_admin.resource_path("posts", post_record),
              params: { record: { title: post_record.title, body_markdown: "# Updated\n\nNew content." } },
              as: :html

        expect(post_record.reload.body_markdown).to eq("# Updated\n\nNew content.")
      end
    end
  end

  describe "tags field type" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::TagResource)
    end

    describe "GET /:resource_name/:id (show)" do
      it "displays tags as badges" do
        post_record = create(:post, category_tags: "ruby,rails,web")
        get iron_admin.resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("ruby")
        expect(response.body).to include("rails")
        expect(response.body).to include("web")
        expect(response.body).to include("bg-indigo-50")
      end

      it "handles empty tags gracefully" do
        post_record = create(:post, category_tags: "")
        get iron_admin.resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
      end

      it "handles nil tags gracefully" do
        post_record = create(:post, category_tags: nil)
        get iron_admin.resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /:resource_name/new" do
      it "renders form with tags input" do
        get iron_admin.new_resource_path("posts"), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("tags-container-category_tags")
        expect(response.body).to include("Type and press Enter")
      end
    end

    describe "GET /:resource_name/:id/edit" do
      it "renders form with existing tags pre-filled" do
        post_record = create(:post, category_tags: "ruby,rails")
        get iron_admin.edit_resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("ruby")
        expect(response.body).to include("rails")
      end
    end

    describe "POST /:resource_name (create)" do
      it "creates record with tags" do
        post iron_admin.resources_path("posts"),
             params: { record: { title: "Tagged Post", category_tags: "ruby,rails" } },
             as: :html

        new_post = Post.last
        expect(new_post.category_tags).to eq("ruby,rails")
      end
    end

    describe "PATCH /:resource_name/:id (update)" do
      it "updates tags" do
        post_record = create(:post, category_tags: "ruby")

        patch iron_admin.resource_path("posts", post_record),
              params: { record: { title: post_record.title, category_tags: "ruby,rails,web" } },
              as: :html

        expect(post_record.reload.category_tags).to eq("ruby,rails,web")
      end

      it "clears tags" do
        post_record = create(:post, category_tags: "ruby,rails")

        patch iron_admin.resource_path("posts", post_record),
              params: { record: { title: post_record.title, category_tags: "" } },
              as: :html

        expect(post_record.reload.category_tags).to eq("")
      end
    end
  end
end
