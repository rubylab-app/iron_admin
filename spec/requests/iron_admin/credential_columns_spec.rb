# frozen_string_literal: true

require "rails_helper"

RSpec.describe "credential columns", type: :request do
  let(:password_hash) { "$2a$12$hashvalueXYZ" }
  let(:reset_token) { "rpt_secret_123" }

  let(:account) do
    Account.create!(
      name: "Ada",
      email: "ada@example.com",
      encrypted_password: password_hash,
      reset_password_token: reset_token,
      variation_digest: "vd_visible_1"
    )
  end

  let(:resource_class) do
    Class.new(IronAdmin::Resource) do
      def self.name = "AccountsAdminResource"

      def self.resource_name = "accounts_admin"

      self.model_class_override = Account
    end
  end

  before do
    Account.create!(name: "Bob", email: "bob@example.com")
    account
    IronAdmin::ResourceRegistry.register(resource_class)
  end

  describe "GET index" do
    it "hides credential values and shows ordinary columns" do
      get iron_admin.resources_path("accounts_admin")

      expect(response.body).to include("Ada")
      expect(response.body).to include("vd_visible_1")
      expect(response.body).not_to include(password_hash)
      expect(response.body).not_to include(reset_token)
    end

    it "lists Bob, who has no credential values" do
      get iron_admin.resources_path("accounts_admin")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bob")
      expect(response.body).not_to include(password_hash)
    end
  end

  describe "GET show" do
    it "hides credential values" do
      get iron_admin.resource_path("accounts_admin", account)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("vd_visible_1")
      expect(response.body).not_to include(password_hash)
      expect(response.body).not_to include(reset_token)
    end
  end

  describe "GET export" do
    it "omits credential values from csv" do
      get iron_admin.export_path("accounts_admin", format: :csv)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("vd_visible_1")
      expect(response.body).not_to include(password_hash)
      expect(response.body).not_to include(reset_token)
    end

    it "omits credential values from json" do
      get iron_admin.export_path("accounts_admin", format: :json)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ada")
      expect(response.body).not_to include(password_hash)
      expect(response.body).not_to include(reset_token)
    end
  end

  describe "search" do
    it "does not list Ada when the query is the reset token" do
      get iron_admin.search_path(q: "rpt_secret")

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Ada")
      expect(response.body).not_to include(reset_token)
    end

    it "does not list Ada when the query is the password hash prefix" do
      get iron_admin.resources_path("accounts_admin", q: "$2a$12")

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Ada")
      expect(response.body).not_to include(password_hash)
    end

    it "still lists Bob when the query is his name" do
      get iron_admin.search_path(q: "Bob")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bob")
      expect(response.body).not_to include(password_hash)
    end
  end

  describe "edit and update" do
    it "does not render credential inputs" do
      get iron_admin.edit_resource_path("accounts_admin", account)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('name="record[name]"')
      expect(response.body).not_to include('name="record[encrypted_password]"')
      expect(response.body).not_to include('name="record[reset_password_token]"')
    end

    it "updates the name and leaves the password hash unchanged" do
      patch iron_admin.resource_path("accounts_admin", account),
            params: { record: { name: "Ada L", encrypted_password: "plain" } }

      account.reload

      expect(account.name).to eq("Ada L")
      expect(account.encrypted_password).to eq(password_hash)
    end
  end

  context "when the resource sets reset_password_token visible" do
    let(:resource_class) do
      Class.new(IronAdmin::Resource) do
        def self.name = "AccountsAdminResource"

        def self.resource_name = "accounts_admin"

        self.model_class_override = Account

        field :reset_password_token, visible: true
      end
    end

    it "shows the token on the show page and still hides the password hash" do
      get iron_admin.resource_path("accounts_admin", account)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(reset_token)
      expect(response.body).not_to include(password_hash)
    end

    it "still omits the token input on the edit form" do
      get iron_admin.edit_resource_path("accounts_admin", account)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('name="record[reset_password_token]"')
      expect(response.body).to include('name="record[name]"')
    end
  end
end
