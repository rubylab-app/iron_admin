# frozen_string_literal: true

require "rails_helper"

RSpec.describe "a scope body that returns nil or false", type: :request do
  let(:tenant) { create(:user) }
  let!(:active_license) { create(:license, user: tenant, status: :active, license_key: "ACTIVE-KEY-9100") }
  let!(:revoked_license) { create(:license, user: tenant, status: :revoked, license_key: "REVOKED-KEY-9100") }

  before do
    IronAdmin::ResourceRegistry.register(resource)
    IronAdmin.configure do |config|
      config.tenant_scope { |scope| scope.where(user_id: tenant.id) }
    end
  end

  describe "a nil body without scope counts" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name = "NilBodyLicenseResource"
        def self.resource_name = "nil_body_licenses"

        index_fields :license_key

        scope :active, -> { where(status: :active) }, default: true
        show_flagged = nil
        scope :flagged, -> { where(status: :revoked) if show_flagged }
      end
    end

    it "answers 200 and lists every license" do
      get iron_admin.resources_path("nil_body_licenses", scope: "flagged"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active_license.license_key)
      expect(response.body).to include(revoked_license.license_key)
    end
  end

  describe "a false body without scope counts" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name = "FalseBodyLicenseResource"
        def self.resource_name = "false_body_licenses"

        index_fields :license_key

        scope :active, -> { where(status: :active) }, default: true
        show_flagged = false
        scope :flagged, -> { show_flagged ? where(status: :revoked) : false }
      end
    end

    it "answers 200 and lists every license" do
      get iron_admin.resources_path("false_body_licenses", scope: "flagged"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(active_license.license_key)
      expect(response.body).to include(revoked_license.license_key)
    end
  end

  describe "a nil body with scope counts" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name = "NilBodyCountLicenseResource"
        def self.resource_name = "nil_body_count_licenses"

        scope_counts true
        index_fields :license_key

        scope :active, -> { where(status: :active) }, default: true
        show_flagged = nil
        scope :flagged, -> { where(status: :revoked) if show_flagged }
      end
    end

    it "answers 200 and draws the nil tab with no number" do
      get iron_admin.resources_path("nil_body_count_licenses", scope: "flagged"), as: :html

      expect(response).to have_http_status(:ok)
      expect(flagged_tab_text).to eq("Flagged")
    end
  end

  def flagged_tab_text
    tab = response.parsed_body.css("a").find do |link|
      href = link["href"].to_s
      href.include?("scope=flagged") && link.text.squish.include?("Flagged")
    end

    tab.text.squish
  end
end
