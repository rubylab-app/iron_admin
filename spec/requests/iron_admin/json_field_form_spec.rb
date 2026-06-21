require "rails_helper"

RSpec.describe "IronAdmin :json field form rendering", type: :request do
  let(:nested_user_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name
        "JsonNestedUserResource"
      end

      def self.resource_name
        "json_nested_users"
      end

      has_many :licenses, nested: true, fields: %i[license_key rules]
    end
  end

  let(:nested_has_one_user_model) do
    Class.new(User) do
      self.table_name = "users"

      def self.name
        "JsonNestedHasOneUser"
      end

      has_one :primary_license, -> { order(:id) }, class_name: "License", foreign_key: :user_id
      accepts_nested_attributes_for :primary_license
    end
  end

  let(:nested_has_one_user_resource) do
    model_class = nested_has_one_user_model

    Class.new(IronAdmin::Resource) do
      self.model_class_override = model_class

      def self.name
        "JsonNestedHasOneUserResource"
      end

      def self.resource_name
        "json_nested_has_one_users"
      end

      has_one :primary_license, nested: true, fields: %i[license_key rules]
    end
  end

  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(nested_user_resource)
    IronAdmin::ResourceRegistry.register(nested_has_one_user_resource)
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

  describe "nested JSON field form rendering" do
    let(:user) { User.create!(name: "Nested", email: "nested@example.com") }
    let!(:license) do
      License.create!(
        user: user,
        license_key: "NESTED-JSON-001",
        license_type: "standard",
        rules: { "limits" => { "seats" => 3 } }
      )
    end

    it "renders nested JSON fields as pretty-printed textareas" do
      get iron_admin.edit_resource_path("json_nested_users", user.id), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="record[licenses_attributes][0][rules]"')
      expect(response.body).to include("<textarea")
      expect(response.body).to include("&quot;seats&quot;: 3")
      expect(response.body).not_to include('"limits" =&gt; {"seats"=&gt;3}')
    end

    it "round-trips nested JSON values through nested attributes" do
      patch iron_admin.resource_path("json_nested_users", user.id),
            params: {
              record: {
                name: user.name,
                email: user.email,
                licenses_attributes: {
                  "0" => {
                    id: license.id,
                    license_key: license.license_key,
                    rules: '{"limits":{"seats":5},"offline":true}',
                  },
                },
              },
            },
            as: :html

      expect(response).to have_http_status(:redirect)
      expect(license.reload.rules).to eq(
        "limits" => { "seats" => 5 },
        "offline" => true
      )
    end

    it "round-trips has_one nested JSON values through nested attributes" do
      patch iron_admin.resource_path("json_nested_has_one_users", user.id),
            params: {
              record: {
                name: user.name,
                email: user.email,
                primary_license_attributes: {
                  id: license.id,
                  license_key: license.license_key,
                  rules: '{"limits":{"seats":8},"offline":false}',
                },
              },
            },
            as: :html

      expect(response).to have_http_status(:redirect)
      expect(license.reload.rules).to eq(
        "limits" => { "seats" => 8 },
        "offline" => false
      )
    end
  end
end
