require "rails_helper"

RSpec.describe "IronAdmin :json field form rendering", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
  end

  describe "GET /:resource_name/:id/edit" do
    let(:user) do
      User.create!(
        name: "Alice",
        email: "alice@example.com",
        preferences: { "tier" => "premium", "score" => 92 }
      )
    end

    it "renders the JSON field as a pretty-printed textarea (not a single-line text input)" do
      get iron_admin.edit_resource_path("users", user.id), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="record[preferences]"')
      expect(response.body).to include("<textarea")
      # JSON content (HTML-escaped) appears between the textarea tags
      expect(response.body).to include("&quot;tier&quot;: &quot;premium&quot;")
      expect(response.body).to include("&quot;score&quot;: 92")
      # And it must NOT contain the broken Hash#to_s rendering (the bug we're fixing)
      expect(response.body).not_to include('"tier" =&gt; "premium"')
    end

    it "renders an empty textarea when the JSON value is nil" do
      user_without_prefs = User.create!(name: "Bob", email: "bob@example.com", preferences: nil)
      get iron_admin.edit_resource_path("users", user_without_prefs.id), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="record[preferences]"')
      expect(response.body).to include("<textarea")
    end
  end

  describe "POST /:resource_name with JSON field" do
    it "round-trips a JSON value through the form" do
      user = User.create!(name: "Carol", email: "carol@example.com", preferences: {})

      patch iron_admin.resource_path("users", user.id), params: {
        record: {
          name: user.name,
          email: user.email,
          preferences: '{"theme":"dark","notifications":true}',
        },
      }, as: :html

      expect(response).to have_http_status(:redirect)
      user.reload
      expect(user.preferences).to eq("theme" => "dark", "notifications" => true)
    end

    it "clears the JSON column when the textarea is submitted empty" do
      user = User.create!(name: "Dan", email: "dan@example.com", preferences: { "tier" => "free" })

      patch iron_admin.resource_path("users", user.id), params: {
        record: { name: user.name, email: user.email, preferences: "" },
      }, as: :html

      expect(response).to have_http_status(:redirect)
      user.reload
      expect(user.preferences).to be_nil
    end

    it "preserves the existing JSON value when the textarea contains malformed JSON" do
      user = User.create!(name: "Eve", email: "eve@example.com", preferences: { "kept" => true })

      patch iron_admin.resource_path("users", user.id), params: {
        record: { name: user.name, email: user.email, preferences: "{not valid json" },
      }, as: :html

      expect(response).to have_http_status(:redirect)
      user.reload
      expect(user.preferences).to eq("kept" => true)
    end
  end
end
