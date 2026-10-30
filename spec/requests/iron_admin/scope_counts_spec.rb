# frozen_string_literal: true

require "rails_helper"

# Scope tabs can show how many records that tab would list. The feature is off
# until the global setting or the resource turns it on.
RSpec.describe "Scope counts", type: :request do
  def scope_tab_text(name)
    label = name.to_s.humanize
    pattern = /\A#{Regexp.escape(label)}(?: \(\d+\))?\z/
    response.parsed_body.css("a").find { |link| link.text.squish.match?(pattern) }&.text&.squish
  end

  def sql_statements(&block)
    statements = []
    callback = lambda { |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      statements << sql unless skipped_sql?(payload, sql)
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    statements
  end

  def skipped_sql?(payload, sql)
    payload[:name] == "SCHEMA" || sql.match?(/SCHEMA|TRANSACTION|\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)\b/)
  end

  def count_sql(statements)
    statements.count { |sql| sql.match?(/\bCOUNT\(/i) }
  end

  def measure(name, params = {}, headers = {})
    sql_statements { get iron_admin.resources_path(name, params), headers: headers, as: :html }
  end

  def normalized_sql(statements)
    statements.map(&:squish)
  end

  def listed_total
    text = response.parsed_body.at("nav[aria-label='Pagination']")&.text.to_s.squish
    text[/of (\d+) results/, 1]
  end

  def stub_status_failure(failing_status, http_status)
    stub_request(:get, %r{https://api\.example\.com/v1/remote_products}).to_return do |request|
      status = Rack::Utils.parse_query(URI(request.uri).query)["status"]
      if status == failing_status
        { status: http_status, body: "nope", headers: { "Content-Type" => "application/json" } }
      else
        body = { data: [{ id: 1, name: "Widget" }], meta: { total: 4 } }
        { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
      end
    end
  end

  describe "license index" do
    let(:license_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name = "CountedLicenseResource"
        def self.resource_name = "counted_licenses"

        scope_counts true
        searchable :license_key
        filter :license_type, type: :select
        index_fields :license_key, :status

        scope :active, -> { where(status: :active) }, default: true
        scope :expired, -> { where(status: :expired) }
        scope :revoked, -> { where(status: :revoked) }, count: false
      end
    end

    before { IronAdmin::ResourceRegistry.register(license_resource) }

    context "with filters, search and a tenant" do
      let(:tenant) { create(:user) }
      let(:outsider) { create(:user) }
      let(:index_params) { { q: "MATCH", filters: { license_type: "standard" } } }

      before do
        IronAdmin.configure do |config|
          config.tenant_scope { |scope| scope.where(user_id: tenant.id) }
        end

        create(:license, user: tenant, status: :active, license_type: "standard", license_key: "MATCH-A")
        create(:license, user: tenant, status: :active, license_type: "standard", license_key: "MATCH-B")
        create(:license, user: tenant, status: :active, license_type: "premium", license_key: "MATCH-C")
        create(:license, user: tenant, status: :active, license_type: "standard", license_key: "OTHER-D")
        create(:license, user: tenant, status: :expired, license_type: "standard", license_key: "MATCH-E")
        create(:license, user: tenant, status: :expired, license_type: "premium", license_key: "MATCH-F")
        create(:license, user: tenant, status: :expired, license_type: "standard", license_key: "OTHER-G")
        create(:license, user: outsider, status: :expired, license_type: "standard", license_key: "MATCH-H")
        create(:license, user: outsider, status: :active, license_type: "standard", license_key: "MATCH-I")
        create(:license, user: tenant, status: :revoked, license_type: "standard", license_key: "MATCH-J")
      end

      it "counts the active tab through the tenant, the filter and the search" do
        get iron_admin.resources_path("counted_licenses", index_params), as: :html

        expect(scope_tab_text("active")).to eq("Active (2)")
      end

      it "counts the expired tab through the same filter, search and tenant" do
        get iron_admin.resources_path("counted_licenses", index_params), as: :html

        expect(scope_tab_text("expired")).to eq("Expired (1)")
      end

      it "omits the count of a scope that sets count: false" do
        get iron_admin.resources_path("counted_licenses", index_params), as: :html

        expect(scope_tab_text("revoked")).to eq("Revoked")
      end

      it "keeps each tab's count when another tab is selected" do
        get iron_admin.resources_path("counted_licenses", index_params.merge(scope: "expired")), as: :html

        expect(scope_tab_text("active")).to eq("Active (2)")
      end
    end

    context "with the default scope and no filter" do
      before do
        create_list(:license, 3, status: :active)
        create(:license, status: :expired)
      end

      it "counts the default scope rather than every record" do
        get iron_admin.resources_path("counted_licenses"), as: :html

        expect(scope_tab_text("active")).to eq("Active (3)")
      end

      it "counts the other scope" do
        get iron_admin.resources_path("counted_licenses"), as: :html

        expect(scope_tab_text("expired")).to eq("Expired (1)")
      end
    end
  end

  describe "user index" do
    let(:user_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "CountedUserResource"
        def self.resource_name = "counted_users"

        scope :active, -> { where(active: true) }, default: true
        scope :inactive, -> { where(active: false) }
        index_fields :name, :email
      end
    end

    before { IronAdmin::ResourceRegistry.register(user_resource) }

    it "shows no number while scope counts are off" do
      create(:user)

      get iron_admin.resources_path("counted_users"), as: :html

      expect(scope_tab_text("active")).to eq("Active")
    end

    context "when the global setting is on" do
      before { IronAdmin.configuration.scope_counts = true }

      it "shows zero when the scope matches nothing" do
        create(:user, active: true)

        get iron_admin.resources_path("counted_users"), as: :html

        expect(scope_tab_text("inactive")).to eq("Inactive (0)")
      end

      it "counts every matching record, not the page" do
        IronAdmin.configuration.per_page = 1
        create_list(:user, 3, active: true)

        get iron_admin.resources_path("counted_users"), as: :html

        expect(scope_tab_text("active")).to eq("Active (3)")
      end
    end

    context "when the resource turns counts on and the global setting is off" do
      let(:user_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name = "OverrideCountUserResource"
          def self.resource_name = "override_count_users"

          scope_counts true
          scope :active, -> { where(active: true) }, default: true
          scope :inactive, -> { where(active: false) }
          index_fields :name, :email
        end
      end

      it "shows the counts" do
        create_list(:user, 2, active: true)

        get iron_admin.resources_path("override_count_users"), as: :html

        expect(scope_tab_text("active")).to eq("Active (2)")
      end
    end

    context "when the resource turns counts off and the global setting is on" do
      let(:user_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name = "SilentCountUserResource"
          def self.resource_name = "silent_count_users"

          scope_counts false
          scope :active, -> { where(active: true) }, default: true
          scope :inactive, -> { where(active: false) }
          index_fields :name, :email
        end
      end

      before { IronAdmin.configuration.scope_counts = true }

      it "shows no number" do
        create(:user)

        get iron_admin.resources_path("silent_count_users"), as: :html

        expect(scope_tab_text("active")).to eq("Active")
      end
    end
  end

  describe "query budget" do
    let(:budget_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "BudgetScopeCountUserResource"
        def self.resource_name = "budget_scope_count_users"

        scope :active, -> { where(active: true) }, default: true
        scope :inactive, -> { where(active: false) }
        index_fields :name, :email
      end
    end

    before do
      IronAdmin.configuration.scope_counts = false
      IronAdmin::ResourceRegistry.register(budget_resource)
      create(:user)
      get iron_admin.resources_path(budget_resource.resource_name), as: :html
    end

    it "adds one count query per counted scope when the setting is on" do
      off = measure(budget_resource.resource_name)
      IronAdmin.configuration.scope_counts = true
      on = measure(budget_resource.resource_name)

      expect(on.size).to eq(off.size + 2)
      expect(count_sql(on)).to eq(count_sql(off) + 2)
    end

    it "adds no query when the page is out of range" do
      IronAdmin.configuration.per_page = 1
      off = measure(budget_resource.resource_name, { page: 9 })
      IronAdmin.configuration.scope_counts = true
      on = measure(budget_resource.resource_name, { page: 9 })

      expect(on.size).to eq(off.size)
      expect(count_sql(on)).to eq(count_sql(off))
    end

    it "adds no count query when the records frame asks for another page" do
      headers = { "Turbo-Frame" => "records" }
      off = measure(budget_resource.resource_name, { page: 1 }, headers)
      IronAdmin.configuration.scope_counts = true
      on = measure(budget_resource.resource_name, { page: 1 }, headers)

      expect(on.size).to eq(off.size)
      expect(count_sql(on)).to eq(count_sql(off))
    end

    it "runs these statements when scope counts are off" do
      statements = normalized_sql(measure(budget_resource.resource_name))

      expected = [
        "SELECT COUNT(*) FROM \"users\" WHERE \"users\".\"active\" = ?",
        "SELECT 1 AS one FROM \"users\" WHERE \"users\".\"active\" = ? LIMIT ? OFFSET ?",
        "SELECT \"users\".* FROM \"users\" WHERE \"users\".\"active\" = ? " \
        "ORDER BY \"users\".\"created_at\" DESC LIMIT ? OFFSET ?",
      ]

      expect(statements).to eq(expected)
    end

    it "does not resolve the current user once per counted scope when a search is active" do
      calls = 0
      IronAdmin.configure do |config|
        config.current_user do
          calls += 1
          nil
        end
      end

      get iron_admin.resources_path(budget_resource.resource_name, q: "User"), as: :html
      without_counts = calls

      calls = 0
      IronAdmin.configuration.scope_counts = true
      get iron_admin.resources_path(budget_resource.resource_name, q: "User"), as: :html

      expect(calls).to eq(without_counts)
    end

    context "with a scope that sets count: false" do
      let(:budget_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name = "PartialScopeCountUserResource"
          def self.resource_name = "partial_scope_count_users"

          scope :active, -> { where(active: true) }, default: true
          scope :inactive, -> { where(active: false) }, count: false
          index_fields :name, :email
        end
      end

      it "skips that scope's count query" do
        off = measure(budget_resource.resource_name)
        IronAdmin.configuration.scope_counts = true
        on = measure(budget_resource.resource_name)

        expect(on.size).to eq(off.size + 1)
        expect(count_sql(on)).to eq(count_sql(off) + 1)
      end
    end

    context "when the resource turns counts off" do
      let(:silent_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name = "SilentBudgetUserResource"
          def self.resource_name = "silent_budget_users"

          scope_counts false
          scope :active, -> { where(active: true) }, default: true
          scope :inactive, -> { where(active: false) }
          index_fields :name, :email
        end
      end

      it "matches the query count of the feature turned off" do
        baseline = measure(budget_resource.resource_name)

        IronAdmin.configuration.scope_counts = true
        IronAdmin::ResourceRegistry.register(silent_resource)
        get iron_admin.resources_path("silent_budget_users"), as: :html
        silent = measure("silent_budget_users")

        expect(silent.size).to eq(baseline.size)
        expect(count_sql(silent)).to eq(count_sql(baseline))
      end
    end
  end

  describe "HTTP adapter" do
    let(:http_resource) do
      Class.new(IronAdmin::Resource) do
        self.adapter_class = :http

        def self.name = "IronAdmin::Resources::RemoteProductResource"
        def self.resource_name = "remote_products"

        scope_counts true
        searchable
        index_fields :name

        scope :active, -> { where(status: "active") }, default: true
        scope :archived, -> { where(status: "archived") }
      end
    end

    before do
      IronAdmin.configuration.http_base_url = "https://api.example.com/v1"
      stub_remote_products
      IronAdmin::ResourceRegistry.register(http_resource)
    end

    context "when the response is a list with no total" do
      def stub_remote_products
        stub_request(:get, %r{https://api\.example\.com/v1/remote_products}).to_return(
          status: 200,
          body: [{ id: 1, name: "Widget" }].to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "shows no number" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(scope_tab_text("active")).to eq("Active")
      end
    end

    context "when the response is an empty list with no total" do
      def stub_remote_products
        stub_request(:get, %r{https://api\.example\.com/v1/remote_products}).to_return(
          status: 200,
          body: [].to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "shows the tab name with no number" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(scope_tab_text("archived")).to eq("Archived")
      end
    end

    context "when records include deleted_at" do
      def stub_remote_products
        stub_request(:get, %r{https://api\.example\.com/v1/remote_products}).to_return(
          status: 200,
          body: [{ id: 1, name: "Widget", deleted_at: nil }].to_json,
          headers: { "Content-Type" => "application/json" }
        )
      end

      it "renders the index" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(response).to have_http_status(:ok)
      end

      it "shows the soft-delete tabs with no number" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(scope_tab_text("with_deleted")).to eq("With deleted")
      end

      it "does not log a failed count" do
        allow(Rails.logger).to receive(:error)

        get iron_admin.resources_path("remote_products"), as: :html

        expect(Rails.logger).not_to have_received(:error)
      end
    end

    context "when the response includes an exact total" do
      def stub_remote_products
        stub_request(:get, %r{https://api\.example\.com/v1/remote_products}).to_return do |request|
          status = Rack::Utils.parse_query(URI(request.uri).query)["status"]
          body = case status
                 when "active" then { data: [{ id: 1, name: "Widget" }], meta: { total: 4 } }
                 when "archived" then { data: [{ id: 2, name: "Gadget" }], meta: { total: 0 } }
                 else [{ id: 1, name: "Widget" }]
                 end
          { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
        end
      end

      it "shows that total on the tab" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(scope_tab_text("active")).to eq("Active (4)")
      end

      it "shows zero when the exact total is zero" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(scope_tab_text("archived")).to eq("Archived (0)")
      end
    end

    context "when one scope's provider request answers 404" do
      def stub_remote_products
        stub_status_failure("archived", 404)
      end

      it "renders the index" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(response).to have_http_status(:ok)
      end

      it "draws the failing tab with no number" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(scope_tab_text("archived")).to eq("Archived")
      end

      it "still counts the other tab" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(scope_tab_text("active")).to eq("Active (4)")
      end

      it "logs the missing record once" do
        allow(Rails.logger).to receive(:error)

        get iron_admin.resources_path("remote_products"), as: :html

        expect(Rails.logger).to have_received(:error).with(
          a_string_starting_with("[IronAdmin] IronAdmin::RecordNotFound:")
        ).once
      end
    end

    context "when one scope's provider request answers 500" do
      def stub_remote_products
        stub_status_failure("archived", 500)
      end

      it "renders the index" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(response).to have_http_status(:ok)
      end

      it "draws the failing tab with no number" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(scope_tab_text("archived")).to eq("Archived")
      end

      it "still counts the other tab" do
        get iron_admin.resources_path("remote_products"), as: :html

        expect(scope_tab_text("active")).to eq("Active (4)")
      end

      it "logs the adapter error once" do
        allow(Rails.logger).to receive(:error)

        get iron_admin.resources_path("remote_products"), as: :html

        expect(Rails.logger).to have_received(:error).with(
          a_string_starting_with("[IronAdmin] IronAdmin::AdapterError:")
        ).once
      end
    end
  end

  describe "a scope whose count raises" do
    let(:raising_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "RaisingScopeCountUserResource"
        def self.resource_name = "raising_scope_count_users"

        scope_counts true
        scope :active, -> { where(active: true) }, default: true
        scope :broken, -> { raise "count failed" }
        index_fields :name, :email
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(raising_resource)
      create(:user, active: true)
      allow(Rails.logger).to receive(:error)
    end

    it "renders the index" do
      get iron_admin.resources_path("raising_scope_count_users"), as: :html

      expect(response).to have_http_status(:ok)
    end

    it "draws the failing tab with no number" do
      get iron_admin.resources_path("raising_scope_count_users"), as: :html

      expect(scope_tab_text("broken")).to eq("Broken")
    end

    it "still counts the other tabs" do
      get iron_admin.resources_path("raising_scope_count_users"), as: :html

      expect(scope_tab_text("active")).to eq("Active (1)")
    end

    it "logs the error" do
      get iron_admin.resources_path("raising_scope_count_users"), as: :html

      expect(Rails.logger).to have_received(:error).with(
        a_string_starting_with("[IronAdmin] RuntimeError: count failed")
      )
    end

    it "lets the selected tab's error reach the listing" do
      expect do
        get iron_admin.resources_path("raising_scope_count_users", scope: "broken"), as: :html
      end.to raise_error(RuntimeError, "count failed")
    end
  end

  describe "a scope body that returns nil" do
    let(:nil_scope_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name = "NilScopeLicenseResource"
        def self.resource_name = "nil_scope_licenses"

        scope_counts true
        index_fields :license_key

        scope :active, -> { where(status: :active) }, default: true
        show_flagged = nil
        scope :flagged, -> { where(status: :revoked) if show_flagged }
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(nil_scope_resource)
      tenant = create(:user)
      outsider = create(:user)
      IronAdmin.configure do |config|
        config.tenant_scope { |scope| scope.where(user_id: tenant.id) }
      end
      create(:license, user: tenant, status: :active)
      create(:license, user: outsider, status: :active)
      allow(Rails.logger).to receive(:error)
    end

    it "draws that tab with no number and logs nothing" do
      get iron_admin.resources_path("nil_scope_licenses"), as: :html

      expect(scope_tab_text("flagged")).to eq("Flagged")
      expect(Rails.logger).not_to have_received(:error)
    end

    it "draws that tab with no number and logs nothing when a search is active" do
      get iron_admin.resources_path("nil_scope_licenses", q: "LIC"), as: :html

      expect(scope_tab_text("flagged")).to eq("Flagged")
      expect(Rails.logger).not_to have_received(:error)
    end
  end

  describe "a count that uses a preloaded association" do
    let(:preloaded_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name = "PreloadedScopeLicenseResource"
        def self.resource_name = "preloaded_scope_licenses"

        scope_counts true
        belongs_to :user
        index_fields :license_key
        filter :holder_role, type: :select,
                             options: [%w[Admin admin], %w[Member member]],
                             scope: ->(value, relation) { relation.where(users: { role: value }) }

        scope :current, -> { all }, default: true
        scope :for_admins, -> { where(users: { role: "admin" }) }
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(preloaded_resource)
      IronAdmin.configuration.per_page = 1
      admins = create_list(:user, 2, role: "admin")
      member = create(:user, role: "member")
      admins.each { |user| create(:license, user: user) }
      create(:license, user: member)
      allow(Rails.logger).to receive(:error)
    end

    it "counts the scope the same way the listing does" do
      get iron_admin.resources_path("preloaded_scope_licenses", scope: "for_admins"), as: :html

      expect(scope_tab_text("for_admins")).to eq("For admins (#{listed_total})")
    end

    it "logs nothing for that scope" do
      get iron_admin.resources_path("preloaded_scope_licenses", scope: "for_admins"), as: :html

      expect(Rails.logger).not_to have_received(:error)
    end

    it "counts the filter the same way the listing does" do
      get iron_admin.resources_path(
        "preloaded_scope_licenses",
        scope: "current",
        filters: { holder_role: "admin" }
      ), as: :html

      expect(scope_tab_text("current")).to eq("Current (#{listed_total})")
    end

    it "logs nothing for that filter" do
      get iron_admin.resources_path(
        "preloaded_scope_licenses",
        scope: "current",
        filters: { holder_role: "admin" }
      ), as: :html

      expect(Rails.logger).not_to have_received(:error)
    end
  end

  describe "scopes the index paginates" do
    let(:paged_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name = "PagedScopeCountUserResource"
        def self.resource_name = "paged_scope_count_users"

        scope_counts true
        index_fields :name, :email

        scope :everyone, -> { all }, default: true
        scope :slim, -> { select(:id, :name, :email) }
        scope :with_licenses, -> { joins(:licenses).group("users.id") }
        scope :license_totals, lambda {
          select("users.*, COUNT(licenses.id) AS n").left_joins(:licenses).group("users.id")
        }
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(paged_resource)
      IronAdmin.configuration.per_page = 1
      people = create_list(:user, 3)
      create_list(:license, 2, user: people.first)
      create(:license, user: people.second)
    end

    def show_scope(name)
      get iron_admin.resources_path("paged_scope_count_users", scope: name), as: :html
    end

    it "renders the multi-column select scope" do
      show_scope("slim")

      expect(response).to have_http_status(:ok)
    end

    it "counts the multi-column select scope as the listing total" do
      show_scope("slim")

      expect(scope_tab_text("slim")).to eq("Slim (#{listed_total})")
    end

    it "renders the grouped scope" do
      show_scope("with_licenses")

      expect(response).to have_http_status(:ok)
    end

    it "counts the grouped scope as the listing total" do
      show_scope("with_licenses")

      expect(scope_tab_text("with_licenses")).to eq("With licenses (#{listed_total})")
    end

    it "renders the grouped select scope" do
      show_scope("license_totals")

      expect(response).to have_http_status(:ok)
    end

    it "counts the grouped select scope as the listing total" do
      show_scope("license_totals")

      expect(scope_tab_text("license_totals")).to eq("License totals (#{listed_total})")
    end
  end
end
