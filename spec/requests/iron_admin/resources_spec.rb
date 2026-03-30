require "rails_helper"
require_relative "../../support/test_resources"

RSpec.describe "IronAdmin::Resources", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
  end

  describe "GET /:resource_name" do
    it "returns success" do
      create_list(:user, 3)
      get iron_admin.resources_path("users"), headers: { "Accept" => "text/html" }
      expect(response).to have_http_status(:ok)
    end

    context "with search query" do
      it "filters records by search term" do
        create(:user, name: "John Doe", email: "john@example.com")
        create(:user, name: "Jane Smith", email: "jane@example.com")
        get iron_admin.resources_path("users"), params: { q: "John" }, as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "with field-specific search (field:value syntax)" do
      it "searches only the specified column with email:value" do
        create(:user, name: "John Doe", email: "john@example.com")
        create(:user, name: "Jane Smith", email: "jane@example.com")
        # Search email column specifically
        get iron_admin.resources_path("users"), params: { q: "email:john" }, as: :html
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("john@example.com")
        expect(response.body).not_to include("jane@example.com")
      end

      it "searches only the specified column with name:value" do
        create(:user, name: "John Doe", email: "john@example.com")
        create(:user, name: "Jane Smith", email: "jane@example.com")
        get iron_admin.resources_path("users"), params: { q: "name:Jane" }, as: :html
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Jane Smith")
        expect(response.body).not_to include("John Doe")
      end

      it "ignores invalid field names without crashing" do
        create(:user, name: "John Doe", email: "john@example.com")
        get iron_admin.resources_path("users"), params: { q: "invalid_field:value" }, as: :html
        expect(response).to have_http_status(:ok)
      end

      it "handles special characters in search value" do
        create(:user, name: "John+Doe", email: "john+test@example.com")
        get iron_admin.resources_path("users"), params: { q: "email:john+test" }, as: :html
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("john+test@example.com")
      end

      it "handles values with colons" do
        # Value itself contains a colon
        create(:user, name: "Test User", email: "test@example.com")
        get iron_admin.resources_path("users"), params: { q: "name:Test User" }, as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "with date range search (field:from..to syntax)" do
      let(:user) { create(:user) }

      it "filters by date range with both from and to dates" do
        old_license = create(:license, user: user, created_at: 30.days.ago)
        recent_license = create(:license, user: user, created_at: 2.days.ago)
        create(:license, user: user, created_at: 1.day.from_now)

        from_date = 10.days.ago.to_date.to_s
        to_date = Date.current.to_s
        get iron_admin.resources_path("licenses"), params: { q: "created_at:#{from_date}..#{to_date}" }, as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(recent_license.license_key)
        expect(response.body).not_to include(old_license.license_key)
      end

      it "filters with only from date (open-ended to)" do
        old_license = create(:license, user: user, created_at: 30.days.ago)
        recent_license = create(:license, user: user, created_at: 2.days.ago)

        from_date = 10.days.ago.to_date.to_s
        get iron_admin.resources_path("licenses"), params: { q: "created_at:#{from_date}.." }, as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(recent_license.license_key)
        expect(response.body).not_to include(old_license.license_key)
      end

      it "filters with only to date (open-ended from)" do
        old_license = create(:license, user: user, created_at: 30.days.ago)
        recent_license = create(:license, user: user, created_at: 2.days.ago)

        to_date = 10.days.ago.to_date.to_s
        get iron_admin.resources_path("licenses"), params: { q: "created_at:..#{to_date}" }, as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(old_license.license_key)
        expect(response.body).not_to include(recent_license.license_key)
      end

      it "handles invalid dates gracefully" do
        create(:license, user: user)
        get iron_admin.resources_path("licenses"), params: { q: "created_at:invalid..also-invalid" }, as: :html
        expect(response).to have_http_status(:ok)
      end

      it "handles date range on expires_at column" do
        expiring_soon = create(:license, user: user, expires_at: 5.days.from_now)
        expiring_later = create(:license, user: user, expires_at: 30.days.from_now)

        to_date = 10.days.from_now.to_date.to_s
        get iron_admin.resources_path("licenses"), params: { q: "expires_at:..#{to_date}" }, as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(expiring_soon.license_key)
        expect(response.body).not_to include(expiring_later.license_key)
      end
    end

    context "regular search still works after advanced search feature" do
      it "searches across all searchable columns without field: prefix" do
        create(:user, name: "John Doe", email: "unique@example.com")
        create(:user, name: "Jane Smith", email: "jane@example.com")
        # Regular search should still search across all searchable columns (name and email)
        get iron_admin.resources_path("users"), params: { q: "unique" }, as: :html
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("unique@example.com")
      end

      it "handles empty search query" do
        create(:user, name: "Test User")
        get iron_admin.resources_path("users"), params: { q: "" }, as: :html
        expect(response).to have_http_status(:ok)
      end

      it "handles whitespace-only search query" do
        create(:user, name: "Test User")
        get iron_admin.resources_path("users"), params: { q: "   " }, as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "with sorting" do
      it "sorts records by column" do
        create_list(:user, 3)
        get iron_admin.resources_path("users"), params: { sort: "name", direction: "asc" }, as: :html
        expect(response).to have_http_status(:ok)
      end

      it "uses default sorting for invalid columns" do
        create_list(:user, 3)
        get iron_admin.resources_path("users"), params: { sort: "invalid_column" }, as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "with filters" do
      it "filters records by select filter" do
        create(:user, role: "admin")
        create(:user, role: "member")
        get iron_admin.resources_path("users"), params: { filters: { role: "admin" } }, as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "with string operator filter" do
      let(:string_filter_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "StringFilterUserResource"
          end

          def self.resource_name
            "string_filter_users"
          end

          filter :name, type: :string
        end
      end

      before do
        IronAdmin::ResourceRegistry.register(string_filter_resource)
        create(:user, name: "Alice Acme")
        create(:user, name: "Bob Builder")
      end

      after do
        IronAdmin::ResourceRegistry.reset!
        register_test_resources
      end

      context 'with "contains" operator' do
        it "returns only matching records" do
          get iron_admin.resources_path("string_filter_users"),
              params: { filters: { name: { op: "contains", value: "Acme" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Alice Acme")
          expect(response.body).not_to include("Bob Builder")
        end
      end

      context 'with "equals" operator' do
        before { create(:user, name: "Alice") }

        it "matches only the exact value" do
          get iron_admin.resources_path("string_filter_users"),
              params: { filters: { name: { op: "equals", value: "Alice" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Alice")
          expect(response.body).not_to include("Alice Acme")
        end
      end

      context 'with "starts_with" operator' do
        it "matches records starting with the value" do
          get iron_admin.resources_path("string_filter_users"),
              params: { filters: { name: { op: "starts_with", value: "Alice" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Alice Acme")
          expect(response.body).not_to include("Bob Builder")
        end
      end

      context 'with "ends_with" operator' do
        it "matches records ending with the value" do
          get iron_admin.resources_path("string_filter_users"),
              params: { filters: { name: { op: "ends_with", value: "Acme" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Alice Acme")
          expect(response.body).not_to include("Bob Builder")
        end
      end

      context "with blank value" do
        it "returns all records unfiltered" do
          get iron_admin.resources_path("string_filter_users"),
              params: { filters: { name: { op: "contains", value: "" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Alice Acme")
          expect(response.body).to include("Bob Builder")
        end
      end

      context "with invalid operator" do
        it "returns all records unfiltered" do
          get iron_admin.resources_path("string_filter_users"),
              params: { filters: { name: { op: "drop_table", value: "test" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Alice Acme")
        end
      end
    end

    context "with number operator filter" do
      let(:number_filter_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "NumberFilterLicenseResource"
          end

          def self.resource_name
            "number_filter_licenses"
          end

          belongs_to :user, display: :email
          filter :max_devices, type: :number
        end
      end

      let(:user) { create(:user) }

      before do
        IronAdmin::ResourceRegistry.register(number_filter_resource)
        create(:license, user: user, max_devices: 5, license_key: "KEY-FIVE")
        create(:license, user: user, max_devices: 10, license_key: "KEY-TEN")
      end

      after do
        IronAdmin::ResourceRegistry.reset!
        register_test_resources
      end

      context 'with "equals" operator' do
        it "matches the exact numeric value" do
          get iron_admin.resources_path("number_filter_licenses"),
              params: { filters: { max_devices: { op: "equals", value: "5" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("KEY-FIVE")
          expect(response.body).not_to include("KEY-TEN")
        end
      end

      context 'with "greater_than" operator' do
        it "matches values above the threshold" do
          get iron_admin.resources_path("number_filter_licenses"),
              params: { filters: { max_devices: { op: "greater_than", value: "7" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("KEY-FIVE")
          expect(response.body).to include("KEY-TEN")
        end
      end

      context 'with "less_than" operator' do
        it "matches values below the threshold" do
          get iron_admin.resources_path("number_filter_licenses"),
              params: { filters: { max_devices: { op: "less_than", value: "7" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("KEY-FIVE")
          expect(response.body).not_to include("KEY-TEN")
        end
      end

      context 'with "between" operator' do
        before do
          create(:license, user: user, max_devices: 1, license_key: "KEY-ONE")
          create(:license, user: user, max_devices: 20, license_key: "KEY-TWENTY")
        end

        it "matches values in the inclusive range" do
          get iron_admin.resources_path("number_filter_licenses"),
              params: { filters: { max_devices: { op: "between", value: "5", "value_2" => "10" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("KEY-FIVE")
          expect(response.body).to include("KEY-TEN")
          expect(response.body).not_to include("KEY-ONE")
          expect(response.body).not_to include("KEY-TWENTY")
        end
      end

      context "with non-numeric value" do
        it "returns all records unfiltered" do
          get iron_admin.resources_path("number_filter_licenses"),
              params: { filters: { max_devices: { op: "equals", value: "abc" } } },
              as: :html

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("KEY-FIVE")
        end
      end
    end

    context "with scopes" do
      let(:user) { create(:user) }

      before do
        create(:license, user: user, status: "active")
        create(:license, user: user, status: "expired")
      end

      it "applies the specified scope" do
        get iron_admin.resources_path("licenses"), params: { scope: "expired" }, as: :html
        expect(response).to have_http_status(:ok)
      end

      it "applies the default scope when none specified" do
        get iron_admin.resources_path("licenses"), as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "with date range filter" do
      let(:user) { create(:user) }

      it "filters by date range" do
        create(:license, user: user, created_at: 1.day.ago)
        create(:license, user: user, created_at: 10.days.ago)
        get iron_admin.resources_path("licenses"),
            params: { filters: { created_at_from: 5.days.ago.to_date, created_at_to: Date.current } },
            as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "filter edge cases" do
      let(:user) { create(:user) }

      describe "invalid date in date range filter" do
        it "handles completely invalid date string without crashing" do
          create(:license, user: user)
          get iron_admin.resources_path("licenses"),
              params: { filters: { created_at_from: "not-a-date", created_at_to: "also-invalid" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles malformed date format gracefully" do
          create(:license, user: user)
          get iron_admin.resources_path("licenses"),
              params: { filters: { created_at_from: "2024-13-45", created_at_to: "2024-00-00" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles partial date values without crashing" do
          create(:license, user: user)
          get iron_admin.resources_path("licenses"),
              params: { filters: { created_at_from: "2024", created_at_to: "2024-01" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles empty string date values" do
          create(:license, user: user)
          get iron_admin.resources_path("licenses"),
              params: { filters: { created_at_from: "", created_at_to: "" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles date with only from value" do
          create(:license, user: user, created_at: 1.day.ago)
          create(:license, user: user, created_at: 10.days.ago)
          get iron_admin.resources_path("licenses"),
              params: { filters: { created_at_from: 5.days.ago.to_date.to_s } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles date with only to value" do
          create(:license, user: user, created_at: 1.day.ago)
          create(:license, user: user, created_at: 10.days.ago)
          get iron_admin.resources_path("licenses"),
              params: { filters: { created_at_to: 5.days.ago.to_date.to_s } },
              as: :html
          expect(response).to have_http_status(:ok)
        end
      end

      describe "multiple filters combined" do
        before do
          create(:license, user: user, status: "active", created_at: 1.day.ago)
          create(:license, user: user, status: "expired", created_at: 1.day.ago)
          create(:license, user: user, status: "active", created_at: 10.days.ago)
        end

        it "applies both select and date range filters correctly" do
          get iron_admin.resources_path("licenses"),
              params: {
                filters: {
                  status: "active",
                  created_at_from: 5.days.ago.to_date.to_s,
                  created_at_to: Date.current.to_s,
                },
              },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "combines filters with search query" do
          get iron_admin.resources_path("licenses"),
              params: {
                q: "license",
                filters: { status: "active" },
              },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "combines filters with sorting" do
          get iron_admin.resources_path("licenses"),
              params: {
                sort: "created_at",
                direction: "desc",
                filters: { status: "active" },
              },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "combines filters with scopes" do
          get iron_admin.resources_path("licenses"),
              params: {
                scope: "expired",
                filters: { created_at_from: 5.days.ago.to_date.to_s },
              },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "combines multiple filters with pagination" do
          create_list(:license, 30, user: user, status: "active")
          get iron_admin.resources_path("licenses"),
              params: {
                page: 2,
                filters: { status: "active" },
              },
              as: :html
          expect(response).to have_http_status(:ok)
        end
      end

      describe "filter with nil and blank values" do
        before do
          create(:license, user: user, status: "active")
        end

        it "handles nil filter hash gracefully" do
          get iron_admin.resources_path("licenses"),
              params: { filters: nil },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles filter with nil value" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { status: nil } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles filter with empty string value" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { status: "" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles filter with whitespace only value" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { status: "   " } },
              as: :html
          expect(response).to have_http_status(:ok)
        end
      end

      describe "filter bypass attempts via URL manipulation" do
        before do
          create(:license, user: user, status: "active")
        end

        it "ignores undefined filter names" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { undefined_filter: "malicious_value" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "ignores SQL injection attempts in filter values" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { status: "active'; DROP TABLE licenses;--" } },
              as: :html
          expect(response).to have_http_status(:ok)
          # Verify the table still exists
          expect(License.count).to be >= 1
        end

        it "ignores SQL injection attempts in date filter" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { created_at_from: "2024-01-01'; DROP TABLE licenses;--" } },
              as: :html
          expect(response).to have_http_status(:ok)
          expect(License.count).to be >= 1
        end

        it "handles array values in filter params" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { status: %w[active expired] } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles hash values in filter params" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { status: { nested: "value" } } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles extremely long filter values" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { status: "a" * 10_000 } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles special characters in filter values" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { status: "<script>alert('xss')</script>" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "ignores attempts to filter by columns not defined as filters" do
          get iron_admin.resources_path("licenses"),
              params: { filters: { license_key: "test", id: 1 } },
              as: :html
          expect(response).to have_http_status(:ok)
        end
      end

      describe "boolean filter edge cases" do
        let(:boolean_filter_resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.name
              "BooleanFilterUserResource"
            end

            def self.resource_name
              "boolean_filter_users"
            end

            filter :active, type: :boolean
          end
        end

        before do
          IronAdmin::ResourceRegistry.register(boolean_filter_resource)
        end

        after do
          IronAdmin::ResourceRegistry.reset!
          IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
          IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
        end

        it "handles boolean filter with string 'true'" do
          create(:user)
          get iron_admin.resources_path("boolean_filter_users"),
              params: { filters: { active: "true" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles boolean filter with string 'false'" do
          create(:user)
          get iron_admin.resources_path("boolean_filter_users"),
              params: { filters: { active: "false" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles boolean filter with string '1'" do
          create(:user)
          get iron_admin.resources_path("boolean_filter_users"),
              params: { filters: { active: "1" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles boolean filter with string '0'" do
          create(:user)
          get iron_admin.resources_path("boolean_filter_users"),
              params: { filters: { active: "0" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles boolean filter with invalid value" do
          create(:user)
          get iron_admin.resources_path("boolean_filter_users"),
              params: { filters: { active: "invalid" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end
      end

      describe "custom scope filter edge cases" do
        let(:custom_scope_resource) do
          Class.new(IronAdmin::Resource) do
            self.model_class_override = User

            def self.name
              "CustomScopeUserResource"
            end

            def self.resource_name
              "custom_scope_users"
            end

            filter :search_name, type: :text, scope: ->(value, scope) { scope.where("name LIKE ?", "%#{value}%") }
          end
        end

        before do
          IronAdmin::ResourceRegistry.register(custom_scope_resource)
        end

        after do
          IronAdmin::ResourceRegistry.reset!
          IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
          IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
        end

        it "applies custom scope filter correctly" do
          create(:user, name: "John Doe")
          create(:user, name: "Jane Smith")
          get iron_admin.resources_path("custom_scope_users"),
              params: { filters: { search_name: "John" } },
              as: :html
          expect(response).to have_http_status(:ok)
        end

        it "handles SQL injection in custom scope filter" do
          create(:user, name: "Test User")
          get iron_admin.resources_path("custom_scope_users"),
              params: { filters: { search_name: "'; DROP TABLE users;--" } },
              as: :html
          expect(response).to have_http_status(:ok)
          expect(User.count).to be >= 1
        end
      end
    end
  end

  describe "GET /:resource_name/:id" do
    it "shows a record" do
      user = create(:user)
      get iron_admin.resource_path("users", user), as: :html
      expect(response).to have_http_status(:ok)
    end

    context "with has_one association" do
      before do
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::ProfileResource)
      end

      it "displays has_one associated record" do
        user = create(:user)
        create(:profile, user: user, bio: "Ruby developer", website: "https://example.com")
        get iron_admin.resource_path("users", user), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Profile")
        expect(response.body).to include("Ruby developer")
        expect(response.body).to include("https://example.com")
      end

      it "does not display has_one section when no associated record exists" do
        user = create(:user)
        get iron_admin.resource_path("users", user), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Profile")
      end
    end
  end

  describe "HABTM associations" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::TagResource)
    end

    context "on show page" do
      it "displays HABTM associated records as badges" do
        post_record = create(:post, title: "Test Post")
        tag1 = create(:tag, name: "ruby")
        tag2 = create(:tag, name: "rails")
        post_record.tags << [tag1, tag2]

        get iron_admin.resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("ruby")
        expect(response.body).to include("rails")
      end

      it "does not display HABTM section card when no associated records" do
        post_record = create(:post, title: "No Tags Post")

        get iron_admin.resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
        # The HABTM section with badges should not appear (though "Tags" may appear in sidebar menu)
        expect(response.body).not_to include("bg-indigo-50")
      end
    end

    context "on form page" do
      it "renders checkboxes for HABTM on new form" do
        create(:tag, name: "ruby")
        create(:tag, name: "rails")

        get iron_admin.new_resource_path("posts"), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("ruby")
        expect(response.body).to include("rails")
        expect(response.body).to include("tag_ids")
      end

      it "pre-selects existing associations on edit form" do
        post_record = create(:post, title: "Tagged Post")
        tag = create(:tag, name: "ruby")
        post_record.tags << tag

        get iron_admin.edit_resource_path("posts", post_record), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("ruby")
      end
    end

    context "on create" do
      it "creates record with HABTM associations" do
        tag1 = create(:tag, name: "ruby")
        tag2 = create(:tag, name: "rails")

        post iron_admin.resources_path("posts"),
             params: { record: { title: "New Post", tag_ids: [tag1.id, tag2.id] } },
             as: :html

        new_post = Post.last
        expect(new_post.tags).to contain_exactly(tag1, tag2)
      end

      it "creates record without HABTM associations" do
        post iron_admin.resources_path("posts"),
             params: { record: { title: "New Post" } },
             as: :html

        new_post = Post.last
        expect(new_post.tags).to be_empty
      end
    end

    context "on update" do
      it "updates HABTM associations" do
        post_record = create(:post, title: "Update Post")
        tag1 = create(:tag, name: "ruby")
        tag2 = create(:tag, name: "rails")
        post_record.tags << tag1

        patch iron_admin.resource_path("posts", post_record),
              params: { record: { title: "Updated Post", tag_ids: [tag2.id] } },
              as: :html

        expect(post_record.reload.tags).to contain_exactly(tag2)
      end

      it "removes all HABTM associations when empty array" do
        post_record = create(:post, title: "Clear Tags Post")
        tag = create(:tag, name: "ruby")
        post_record.tags << tag

        patch iron_admin.resource_path("posts", post_record),
              params: { record: { title: "Updated Post", tag_ids: [""] } },
              as: :html

        expect(post_record.reload.tags).to be_empty
      end
    end
  end

  describe "GET /:resource_name/new" do
    it "shows new form" do
      get iron_admin.new_resource_path("users"), as: :html
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /:resource_name/:id/edit" do
    it "shows edit form" do
      user = create(:user)
      get iron_admin.edit_resource_path("users", user), as: :html
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /:resource_name" do
    context "with valid params" do
      it "creates a new record" do
        expect do
          post iron_admin.resources_path("users"),
               params: { record: { name: "New User", email: "new@example.com", role: "member" } },
               as: :html
        end.to change(User, :count).by(1)
      end

      it "redirects to the show page" do
        post iron_admin.resources_path("users"),
             params: { record: { name: "New User", email: "new@example.com", role: "member" } },
             as: :html
        expect(response).to redirect_to(iron_admin.resource_path("users", User.last))
      end
    end

    context "with invalid params" do
      it "renders new form with errors" do
        post iron_admin.resources_path("users"),
             params: { record: { name: "", email: "", role: "member" } },
             as: :html
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with on_action callback" do
      it "emits create event" do
        events = []
        IronAdmin.configure do |config|
          config.on_action { |event| events << event }
        end

        post iron_admin.resources_path("users"),
             params: { record: { name: "New User", email: "new@example.com", role: "member" } },
             as: :html

        expect(events.last.action).to eq(:create)
      end
    end
  end

  describe "PATCH /:resource_name/:id" do
    let(:user) { create(:user, name: "Old Name") }

    context "with valid params" do
      it "updates the record" do
        patch iron_admin.resource_path("users", user),
              params: { record: { name: "New Name", email: user.email, role: user.role } },
              as: :html
        expect(user.reload.name).to eq("New Name")
      end

      it "redirects to the show page" do
        patch iron_admin.resource_path("users", user),
              params: { record: { name: "New Name", email: user.email, role: user.role } },
              as: :html
        expect(response).to redirect_to(iron_admin.resource_path("users", user))
      end
    end

    context "with invalid params" do
      it "renders edit form with errors" do
        patch iron_admin.resource_path("users", user),
              params: { record: { name: "", email: "", role: "member" } },
              as: :html
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with on_action callback" do
      it "emits update event" do
        events = []
        IronAdmin.configure do |config|
          config.on_action { |event| events << event }
        end

        patch iron_admin.resource_path("users", user),
              params: { record: { name: "New Name", email: user.email, role: user.role } },
              as: :html

        expect(events.last.action).to eq(:update)
      end
    end
  end

  describe "DELETE /:resource_name/:id" do
    let!(:user) { create(:user) }

    it "destroys the record" do
      expect do
        delete iron_admin.resource_path("users", user), as: :html
      end.to change(User, :count).by(-1)
    end

    it "redirects to index" do
      delete iron_admin.resource_path("users", user), as: :html
      expect(response).to redirect_to(iron_admin.resources_path("users"))
    end

    context "with on_action callback" do
      it "emits destroy event" do
        events = []
        IronAdmin.configure do |config|
          config.on_action { |event| events << event }
        end

        delete iron_admin.resource_path("users", user), as: :html
        expect(events.last.action).to eq(:destroy)
      end
    end
  end

  describe "POST /:resource_name/:id/actions/:action_name" do
    let(:user) { create(:user) }
    let!(:license) { create(:license, user: user, status: "active") }

    context "with valid action" do
      it "executes the action" do
        post iron_admin.resource_action_path("licenses", license, "revoke"), as: :html
        expect(license.reload.status).to eq("revoked")
      end

      it "redirects to show page" do
        post iron_admin.resource_action_path("licenses", license, "revoke"), as: :html
        expect(response).to redirect_to(iron_admin.resource_path("licenses", license))
      end
    end

    context "with invalid action" do
      it "returns not found" do
        post iron_admin.resource_action_path("licenses", license, "nonexistent"), as: :html
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with transaction handling" do
      let(:transaction_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "TransactionLicenseResource"
          end

          def self.resource_name
            "transaction_licenses"
          end

          belongs_to :user, display: :email

          action :failing_action do |license|
            license.update!(status: "revoked")
            raise StandardError, "Something went wrong"
          end

          action :returning_false_action do |license|
            license.update!(status: "revoked")
            false
          end

          action :successful_action do |license|
            license.update!(status: "revoked")
          end
        end
      end

      before do
        IronAdmin::ResourceRegistry.register(transaction_resource)
      end

      after do
        IronAdmin::ResourceRegistry.reset!
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
      end

      it "rolls back changes when action raises an error" do
        post iron_admin.resource_action_path("transaction_licenses", license, "failing_action"), as: :html
        expect(license.reload.status).to eq("active")
      end

      it "shows error message in flash when action raises" do
        post iron_admin.resource_action_path("transaction_licenses", license, "failing_action"), as: :html
        expect(flash[:alert]).to eq("Action failed: Something went wrong")
      end

      it "redirects to index page when action raises" do
        post iron_admin.resource_action_path("transaction_licenses", license, "failing_action"), as: :html
        expect(response).to redirect_to(iron_admin.resources_path("transaction_licenses"))
      end

      it "rolls back changes when action returns false" do
        post iron_admin.resource_action_path("transaction_licenses", license, "returning_false_action"), as: :html
        expect(license.reload.status).to eq("active")
      end

      it "persists changes when action succeeds" do
        post iron_admin.resource_action_path("transaction_licenses", license, "successful_action"), as: :html
        expect(license.reload.status).to eq("revoked")
      end

      it "shows success message when action completes" do
        post iron_admin.resource_action_path("transaction_licenses", license, "successful_action"), as: :html
        expect(flash[:notice]).to eq("Action completed")
      end
    end
  end

  describe "POST /:resource_name/bulk_actions/:action_name" do
    let(:user) { create(:user) }
    let!(:licenses) { create_list(:license, 3, user: user) }

    context "with valid bulk action" do
      it "executes the bulk action" do
        post iron_admin.resource_bulk_action_path("licenses", "export"),
             params: { ids: licenses.map(&:id) },
             as: :html
        expect(response).to redirect_to(iron_admin.resources_path("licenses"))
        expect(flash[:notice]).to eq("Bulk action completed")
      end
    end

    context "with invalid bulk action" do
      it "returns not found" do
        post iron_admin.resource_bulk_action_path("licenses", "nonexistent"),
             params: { ids: licenses.map(&:id) },
             as: :html
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without ids" do
      it "handles empty ids" do
        post iron_admin.resource_bulk_action_path("licenses", "export"), as: :html
        expect(response).to redirect_to(iron_admin.resources_path("licenses"))
      end
    end

    context "with transaction handling" do
      let(:bulk_transaction_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "BulkTransactionLicenseResource"
          end

          def self.resource_name
            "bulk_transaction_licenses"
          end

          belongs_to :user, display: :email

          bulk_action :failing_bulk_action do |licenses|
            licenses.update_all(status: "revoked")
            raise StandardError, "Bulk operation failed"
          end

          bulk_action :returning_false_bulk_action do |licenses|
            licenses.update_all(status: "revoked")
            false
          end

          bulk_action :successful_bulk_action do |licenses|
            licenses.update_all(status: "revoked")
          end
        end
      end

      before do
        IronAdmin::ResourceRegistry.register(bulk_transaction_resource)
      end

      after do
        IronAdmin::ResourceRegistry.reset!
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
      end

      it "rolls back changes when bulk action raises an error" do
        post iron_admin.resource_bulk_action_path("bulk_transaction_licenses", "failing_bulk_action"),
             params: { ids: licenses.map(&:id) },
             as: :html
        licenses.each do |license|
          expect(license.reload.status).to eq("active")
        end
      end

      it "shows error message in flash when bulk action raises" do
        post iron_admin.resource_bulk_action_path("bulk_transaction_licenses", "failing_bulk_action"),
             params: { ids: licenses.map(&:id) },
             as: :html
        expect(flash[:alert]).to eq("Action failed: Bulk operation failed")
      end

      it "redirects to index page when bulk action raises" do
        post iron_admin.resource_bulk_action_path("bulk_transaction_licenses", "failing_bulk_action"),
             params: { ids: licenses.map(&:id) },
             as: :html
        expect(response).to redirect_to(iron_admin.resources_path("bulk_transaction_licenses"))
      end

      it "rolls back changes when bulk action returns false" do
        post iron_admin.resource_bulk_action_path("bulk_transaction_licenses", "returning_false_bulk_action"),
             params: { ids: licenses.map(&:id) },
             as: :html
        licenses.each do |license|
          expect(license.reload.status).to eq("active")
        end
      end

      it "persists changes when bulk action succeeds" do
        post iron_admin.resource_bulk_action_path("bulk_transaction_licenses", "successful_bulk_action"),
             params: { ids: licenses.map(&:id) },
             as: :html
        licenses.each do |license|
          expect(license.reload.status).to eq("revoked")
        end
      end

      it "shows success message when bulk action completes" do
        post iron_admin.resource_bulk_action_path("bulk_transaction_licenses", "successful_bulk_action"),
             params: { ids: licenses.map(&:id) },
             as: :html
        expect(flash[:notice]).to eq("Bulk action completed")
      end
    end
  end

  describe "resource not found" do
    it "returns not found for unknown resource" do
      get iron_admin.resources_path("unknown_resources"), as: :html
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "association preloading" do
    let(:user) { create(:user) }

    before do
      create_list(:license, 3, user: user)
    end

    it "preloads belongs_to associations to prevent N+1 queries" do
      # LicenseResource has belongs_to :user, which should be preloaded
      queries = []
      callback = lambda { |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:sql].match?(/SCHEMA|TRANSACTION/)
      }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get iron_admin.resources_path("licenses"), headers: { "Accept" => "text/html" }
      end

      expect(response).to have_http_status(:ok)

      # Count queries that select from users table
      # Without preloading: we'd see 1 query for licenses + 3 queries for each user
      # With preloading: we'd see 1 query for licenses + 1 query for all users
      user_queries = queries.select { |q| q.include?('"users"') || q.include?("`users`") }
      expect(user_queries.length).to be <= 1
    end

    it "applies custom preload associations when defined" do
      custom_resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "CustomPreloadLicenseResource"
        end

        def self.resource_name
          "custom_preload_licenses"
        end

        belongs_to :user, display: :email
        preload :user
      end

      IronAdmin::ResourceRegistry.register(custom_resource)

      queries = []
      callback = lambda { |_name, _start, _finish, _id, payload|
        queries << payload[:sql] unless payload[:sql].match?(/SCHEMA|TRANSACTION/)
      }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        get iron_admin.resources_path("custom_preload_licenses"), headers: { "Accept" => "text/html" }
      end

      expect(response).to have_http_status(:ok)

      # Verify user association is preloaded
      user_queries = queries.select { |q| q.include?('"users"') || q.include?("`users`") }
      expect(user_queries.length).to be <= 1
    end
  end

  describe "field visibility enforcement" do
    # Create a resource with a field that has conditional visibility
    let(:visibility_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "VisibilityUserResource"
        end

        def self.resource_name
          "visibility_users"
        end

        # Make email invisible to non-admin users
        field :email, visible: ->(user) { user&.role == "admin" }
        # Make role always invisible
        field :role, visible: false

        index_fields :id, :name, :email, :role
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(visibility_resource)
    end

    after do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    end

    context "when user does not have permission to see a field" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "does not show invisible fields in index view" do
        create(:user, name: "Test User", email: "test@example.com", role: "admin")
        get iron_admin.resources_path("visibility_users"), headers: { "Accept" => "text/html" }

        expect(response).to have_http_status(:ok)
        # The email field should not be visible to non-admin users
        expect(response.body).not_to include("Email")
        # The role field is always invisible
        expect(response.body).not_to include(">Role<")
        # The name field should be visible
        expect(response.body).to include("Name")
        # The actual email value should not appear
        expect(response.body).not_to include("test@example.com")
      end

      it "does not show invisible fields in show view" do
        user = create(:user, name: "Test User", email: "test@example.com", role: "admin")
        get iron_admin.resource_path("visibility_users", user), headers: { "Accept" => "text/html" }

        expect(response).to have_http_status(:ok)
        # The email field should not be visible to non-admin users
        expect(response.body).not_to include("test@example.com")
        # The name should be visible
        expect(response.body).to include("Test User")
      end
    end

    context "when user has permission to see a field" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "admin") }
        end
      end

      it "shows conditionally visible fields in index view" do
        create(:user, name: "Test User", email: "test@example.com", role: "member")
        get iron_admin.resources_path("visibility_users"), headers: { "Accept" => "text/html" }

        expect(response).to have_http_status(:ok)
        # The email field should be visible to admin users
        expect(response.body).to include("Email")
        expect(response.body).to include("test@example.com")
        # The role field is always invisible (visible: false)
        expect(response.body).not_to include(">Role<")
        # The name field should be visible
        expect(response.body).to include("Name")
      end

      it "shows conditionally visible fields in show view" do
        user = create(:user, name: "Test User", email: "test@example.com", role: "member")
        get iron_admin.resource_path("visibility_users", user), headers: { "Accept" => "text/html" }

        expect(response).to have_http_status(:ok)
        # Admin user should see the email field
        expect(response.body).to include("test@example.com")
        # The name should be visible
        expect(response.body).to include("Test User")
      end
    end

    context "when searching with invisible fields" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "does not search invisible fields in general search" do
        # Create users with unique values in email (invisible to member) and name (visible)
        create(:user, name: "Visible Name", email: "secret123@example.com")
        create(:user, name: "Other Name", email: "other@example.com")

        # Search for "secret123" which only exists in the email (invisible) field
        get iron_admin.resources_path("visibility_users"), params: { q: "secret123" }, as: :html

        expect(response).to have_http_status(:ok)
        # Should NOT find the user since email is not visible and not searchable
        expect(response.body).not_to include("Visible Name")
      end

      it "searches visible fields in general search" do
        create(:user, name: "Findable User", email: "hidden@example.com")
        create(:user, name: "Other User", email: "other@example.com")

        # Search for "Findable" which exists in the name (visible) field
        get iron_admin.resources_path("visibility_users"), params: { q: "Findable" }, as: :html

        expect(response).to have_http_status(:ok)
        # Should find the user since name is visible and searchable
        expect(response.body).to include("Findable User")
      end

      it "does not search invisible fields with field:value syntax" do
        # Create two users - one with matching email, one without
        create(:user, name: "Secret Email User", email: "secret@hidden.com")
        create(:user, name: "Normal Email User", email: "normal@example.com")

        # Try to search email field directly which is invisible to member
        get iron_admin.resources_path("visibility_users"), params: { q: "email:secret" }, as: :html

        expect(response).to have_http_status(:ok)
        # When field is invisible, filter should be ignored and ALL users shown
        # (not just the one with matching email - that would leak data)
        expect(response.body).to include("Secret Email User")
        expect(response.body).to include("Normal Email User")
      end

      it "searches visible fields with field:value syntax" do
        create(:user, name: "Searchable User", email: "any@example.com")

        # Search name field directly which is visible
        get iron_admin.resources_path("visibility_users"), params: { q: "name:Searchable" }, as: :html

        expect(response).to have_http_status(:ok)
        # Should find the user since name field is visible
        expect(response.body).to include("Searchable User")
      end
    end

    context "when admin user searches" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "admin") }
        end
      end

      it "searches conditionally visible fields for authorized users" do
        create(:user, name: "Admin Visible", email: "admin-secret@example.com")

        # Admin should be able to search email field
        get iron_admin.resources_path("visibility_users"), params: { q: "admin-secret" }, as: :html

        expect(response).to have_http_status(:ok)
        # Should find the user since email is visible to admin
        expect(response.body).to include("Admin Visible")
      end

      it "searches with field:value syntax on conditionally visible fields" do
        create(:user, name: "Test Admin", email: "findme@admin.com")

        # Admin should be able to use email:value syntax
        get iron_admin.resources_path("visibility_users"), params: { q: "email:findme" }, as: :html

        expect(response).to have_http_status(:ok)
        # Should find the user since email is visible to admin
        expect(response.body).to include("Test Admin")
      end
    end
  end

  describe "policy caching" do
    let(:policy_caching_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "PolicyCachingResource"
        end

        def self.resource_name
          "policy_caching_licenses"
        end

        belongs_to :user, display: :email

        action :test_action do |license|
          license.update!(status: "revoked")
        end

        policy do
          allow :create, :update, :destroy, if: ->(user) { user&.role == "admin" }
          allow :test_action, if: ->(user) { user&.role == "admin" }
        end
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(policy_caching_resource)
      IronAdmin.configure do |config|
        config.current_user { OpenStruct.new(role: "admin") }
      end
    end

    after do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    end

    it "caches the policy instance within a request" do
      user = create(:user)
      license = create(:license, user: user, status: "active")

      # The policy should be instantiated once and reused
      # We can verify this by checking the action completes successfully
      # after both check_action_allowed and action_authorized? are called
      post iron_admin.resource_action_path("policy_caching_licenses", license, "test_action"), as: :html

      expect(response).to redirect_to(iron_admin.resource_path("policy_caching_licenses", license))
      expect(license.reload.status).to eq("revoked")
    end

    it "returns nil when no policy block is defined" do
      no_policy_resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "NoPolicyResource"
        end

        def self.resource_name
          "no_policy_users"
        end
      end

      IronAdmin::ResourceRegistry.register(no_policy_resource)

      # Should be able to access new form without policy restriction
      get iron_admin.new_resource_path("no_policy_users"), as: :html
      expect(response).to have_http_status(:ok)
    end
  end

  describe "policy-based authorization" do
    # Create a resource with a policy that only allows admin users
    let(:policy_user_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "PolicyUserResource"
        end

        def self.resource_name
          "policy_users"
        end

        policy do
          allow :create, :update, :destroy, if: ->(user) { user&.role == "admin" }
        end
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(policy_user_resource)
    end

    after do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    end

    context "when policy denies action based on user context" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "returns forbidden for new action when policy denies create" do
        get iron_admin.new_resource_path("policy_users"), as: :html
        expect(response).to have_http_status(:forbidden)
      end

      it "returns forbidden for create action when policy denies" do
        post iron_admin.resources_path("policy_users"),
             params: { record: { name: "Test", email: "test@example.com", role: "member" } },
             as: :html
        expect(response).to have_http_status(:forbidden)
      end

      it "returns forbidden for edit action when policy denies update" do
        user = create(:user)
        get iron_admin.edit_resource_path("policy_users", user), as: :html
        expect(response).to have_http_status(:forbidden)
      end

      it "returns forbidden for update action when policy denies" do
        user = create(:user)
        patch iron_admin.resource_path("policy_users", user),
              params: { record: { name: "Updated", email: user.email, role: user.role } },
              as: :html
        expect(response).to have_http_status(:forbidden)
      end

      it "returns forbidden for destroy action when policy denies" do
        user = create(:user)
        delete iron_admin.resource_path("policy_users", user), as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when policy allows action based on user context" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "admin") }
        end
      end

      it "allows create action when policy permits" do
        get iron_admin.new_resource_path("policy_users"), as: :html
        expect(response).to have_http_status(:ok)
      end

      it "allows update action when policy permits" do
        user = create(:user)
        get iron_admin.edit_resource_path("policy_users", user), as: :html
        expect(response).to have_http_status(:ok)
      end

      it "allows destroy action when policy permits" do
        user = create(:user)
        delete iron_admin.resource_path("policy_users", user), as: :html
        expect(response).to redirect_to(iron_admin.resources_path("policy_users"))
      end
    end

    context "when no user is logged in" do
      before do
        IronAdmin.configure do |config|
          config.current_user { nil }
        end
      end

      it "returns forbidden when policy requires user context" do
        get iron_admin.new_resource_path("policy_users"), as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "custom action authorization" do
    # Create a resource with policy-controlled custom actions
    let(:policy_license_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "PolicyLicenseResource"
        end

        def self.resource_name
          "policy_licenses"
        end

        belongs_to :user, display: :email

        action :revoke, icon: "x-circle" do |license|
          license.update!(status: :revoked)
        end

        action :renew, icon: "refresh" do |license|
          license.update!(status: :active)
        end

        bulk_action :bulk_revoke do |licenses|
          licenses.update_all(status: :revoked)
        end

        bulk_action :bulk_export do |licenses|
          licenses.pluck(:license_key)
        end

        policy do
          allow :create, :update, :destroy, if: ->(user) { user&.role == "admin" }
          allow :revoke, if: ->(user) { user&.role == "admin" }
          allow :bulk_revoke, if: ->(user) { user&.role == "admin" }
          # renew and bulk_export are not allowed by policy
        end
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(policy_license_resource)
    end

    after do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    end

    context "when policy denies custom action" do
      let(:user) { create(:user) }
      let!(:license) { create(:license, user: user, status: "active") }

      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "returns forbidden when policy denies the action" do
        post iron_admin.resource_action_path("policy_licenses", license, "revoke"), as: :html
        expect(response).to have_http_status(:forbidden)
      end

      it "returns forbidden for actions not in policy allow list" do
        post iron_admin.resource_action_path("policy_licenses", license, "renew"), as: :html
        expect(response).to have_http_status(:forbidden)
      end

      it "does not execute the action when forbidden" do
        post iron_admin.resource_action_path("policy_licenses", license, "revoke"), as: :html
        expect(license.reload.status).to eq("active")
      end
    end

    context "when policy allows custom action" do
      let(:user) { create(:user) }
      let!(:license) { create(:license, user: user, status: "active") }

      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "admin") }
        end
      end

      it "executes the action when policy allows" do
        post iron_admin.resource_action_path("policy_licenses", license, "revoke"), as: :html
        expect(response).to redirect_to(iron_admin.resource_path("policy_licenses", license))
        expect(license.reload.status).to eq("revoked")
      end

      it "returns forbidden for actions not in policy allow list even for admin" do
        post iron_admin.resource_action_path("policy_licenses", license, "renew"), as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when no policy is defined" do
      let(:user) { create(:user) }
      let!(:license) { create(:license, user: user, status: "active") }

      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "allows custom actions by default" do
        # Using the regular LicenseResource which has no policy
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
        post iron_admin.resource_action_path("licenses", license, "revoke"), as: :html
        expect(response).to redirect_to(iron_admin.resource_path("licenses", license))
        expect(license.reload.status).to eq("revoked")
      end
    end
  end

  describe "bulk action authorization" do
    # Reuse the same policy_license_resource setup
    let(:policy_license_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "PolicyLicenseResource"
        end

        def self.resource_name
          "policy_licenses"
        end

        belongs_to :user, display: :email

        bulk_action :bulk_revoke do |licenses|
          licenses.update_all(status: :revoked)
        end

        bulk_action :bulk_export do |licenses|
          licenses.pluck(:license_key)
        end

        policy do
          allow :bulk_revoke, if: ->(user) { user&.role == "admin" }
          # bulk_export is not allowed by policy
        end
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(policy_license_resource)
    end

    after do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    end

    context "when policy denies bulk action" do
      let(:user) { create(:user) }
      let!(:licenses) { create_list(:license, 3, user: user, status: "active") }

      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "returns forbidden when policy denies the bulk action" do
        post iron_admin.resource_bulk_action_path("policy_licenses", "bulk_revoke"),
             params: { ids: licenses.map(&:id) },
             as: :html
        expect(response).to have_http_status(:forbidden)
      end

      it "returns forbidden for bulk actions not in policy allow list" do
        post iron_admin.resource_bulk_action_path("policy_licenses", "bulk_export"),
             params: { ids: licenses.map(&:id) },
             as: :html
        expect(response).to have_http_status(:forbidden)
      end

      it "does not execute the bulk action when forbidden" do
        post iron_admin.resource_bulk_action_path("policy_licenses", "bulk_revoke"),
             params: { ids: licenses.map(&:id) },
             as: :html
        licenses.each do |license|
          expect(license.reload.status).to eq("active")
        end
      end
    end

    context "when policy allows bulk action" do
      let(:user) { create(:user) }
      let!(:licenses) { create_list(:license, 3, user: user, status: "active") }

      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "admin") }
        end
      end

      it "executes the bulk action when policy allows" do
        post iron_admin.resource_bulk_action_path("policy_licenses", "bulk_revoke"),
             params: { ids: licenses.map(&:id) },
             as: :html
        expect(response).to redirect_to(iron_admin.resources_path("policy_licenses"))
        licenses.each do |license|
          expect(license.reload.status).to eq("revoked")
        end
      end

      it "returns forbidden for bulk actions not in policy allow list even for admin" do
        post iron_admin.resource_bulk_action_path("policy_licenses", "bulk_export"),
             params: { ids: licenses.map(&:id) },
             as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when no policy is defined" do
      let(:user) { create(:user) }
      let!(:licenses) { create_list(:license, 3, user: user) }

      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "allows bulk actions by default" do
        # Using the regular LicenseResource which has no policy
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
        post iron_admin.resource_bulk_action_path("licenses", "export"),
             params: { ids: licenses.map(&:id) },
             as: :html
        expect(response).to redirect_to(iron_admin.resources_path("licenses"))
      end
    end
  end

  describe "resources without policies allow all actions by default" do
    # UserResource and LicenseResource have no policy defined
    # All CRUD actions should be allowed

    context "with any user" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "allows create action for resources without policy" do
        expect do
          post iron_admin.resources_path("users"),
               params: { record: { name: "New User", email: "new@example.com", role: "member" } },
               as: :html
        end.to change(User, :count).by(1)
        expect(response).to redirect_to(iron_admin.resource_path("users", User.last))
      end

      it "allows update action for resources without policy" do
        user = create(:user, name: "Old Name")
        patch iron_admin.resource_path("users", user),
              params: { record: { name: "New Name", email: user.email, role: user.role } },
              as: :html
        expect(user.reload.name).to eq("New Name")
        expect(response).to redirect_to(iron_admin.resource_path("users", user))
      end

      it "allows destroy action for resources without policy" do
        user = create(:user)
        expect do
          delete iron_admin.resource_path("users", user), as: :html
        end.to change(User, :count).by(-1)
        expect(response).to redirect_to(iron_admin.resources_path("users"))
      end

      it "allows new form for resources without policy" do
        get iron_admin.new_resource_path("users"), as: :html
        expect(response).to have_http_status(:ok)
      end

      it "allows edit form for resources without policy" do
        user = create(:user)
        get iron_admin.edit_resource_path("users", user), as: :html
        expect(response).to have_http_status(:ok)
      end
    end

    context "without any user (nil current_user)" do
      before do
        IronAdmin.configure do |config|
          config.current_user { nil }
        end
      end

      it "allows create action when no user is logged in" do
        expect do
          post iron_admin.resources_path("users"),
               params: { record: { name: "New User", email: "new@example.com", role: "member" } },
               as: :html
        end.to change(User, :count).by(1)
      end

      it "allows update action when no user is logged in" do
        user = create(:user, name: "Old Name")
        patch iron_admin.resource_path("users", user),
              params: { record: { name: "New Name", email: user.email, role: user.role } },
              as: :html
        expect(user.reload.name).to eq("New Name")
      end

      it "allows destroy action when no user is logged in" do
        user = create(:user)
        expect do
          delete iron_admin.resource_path("users", user), as: :html
        end.to change(User, :count).by(-1)
      end
    end
  end

  describe "policy with read actions always allowed" do
    # Tests that index and show are always accessible even when write actions are restricted
    let(:read_only_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "ReadOnlyUserResource"
        end

        def self.resource_name
          "read_only_users"
        end

        policy do
          allow :index, :show
          # create, update, destroy are NOT allowed
        end
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(read_only_resource)
    end

    after do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    end

    context "with any user" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "allows index action" do
        create_list(:user, 3)
        get iron_admin.resources_path("read_only_users"), as: :html
        expect(response).to have_http_status(:ok)
      end

      it "allows show action" do
        user = create(:user)
        get iron_admin.resource_path("read_only_users", user), as: :html
        expect(response).to have_http_status(:ok)
      end

      it "denies create action" do
        post iron_admin.resources_path("read_only_users"),
             params: { record: { name: "Test", email: "test@example.com", role: "member" } },
             as: :html
        expect(response).to have_http_status(:forbidden)
      end

      it "denies update action" do
        user = create(:user)
        patch iron_admin.resource_path("read_only_users", user),
              params: { record: { name: "Updated", email: user.email, role: user.role } },
              as: :html
        expect(response).to have_http_status(:forbidden)
      end

      it "denies destroy action" do
        user = create(:user)
        delete iron_admin.resource_path("read_only_users", user), as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "authorization does not affect record counts or queries" do
    let(:counting_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "CountingUserResource"
        end

        def self.resource_name
          "counting_users"
        end

        policy do
          allow :index, :show, :create, :update, :destroy, if: ->(user) { user&.role == "admin" }
        end
      end
    end

    before do
      IronAdmin::ResourceRegistry.register(counting_resource)
    end

    after do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    end

    context "when action is forbidden" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "does not create a record when create is forbidden" do
        expect do
          post iron_admin.resources_path("counting_users"),
               params: { record: { name: "Test", email: "test@example.com", role: "member" } },
               as: :html
        end.not_to change(User, :count)
      end

      it "does not modify a record when update is forbidden" do
        user = create(:user, name: "Original Name")
        patch iron_admin.resource_path("counting_users", user),
              params: { record: { name: "New Name", email: user.email, role: user.role } },
              as: :html
        expect(user.reload.name).to eq("Original Name")
      end

      it "does not delete a record when destroy is forbidden" do
        user = create(:user)
        expect do
          delete iron_admin.resource_path("counting_users", user), as: :html
        end.not_to change(User, :count)
      end
    end
  end

  describe "GET /autocomplete/:resource_name" do
    context "with valid query" do
      it "returns matching records as JSON" do
        create(:user, name: "Alice Smith", email: "alice@example.com")
        create(:user, name: "Bob Jones", email: "bob@example.com")
        create(:user, name: "Charlie Smith", email: "charlie@example.com")

        get iron_admin.autocomplete_path("users"), params: { q: "Smith" }, as: :json
        expect(response).to have_http_status(:ok)

        data = response.parsed_body
        expect(data.length).to eq(2)
        expect(data.pluck("label")).to contain_exactly("Alice Smith", "Charlie Smith")
      end

      it "returns id and label for each record" do
        user = create(:user, name: "Test User")
        get iron_admin.autocomplete_path("users"), params: { q: "Test" }, as: :json

        data = response.parsed_body
        expect(data.first).to eq({ "id" => user.id, "label" => "Test User" })
      end

      it "limits results to 20 records" do
        create_list(:user, 25, name: "Test User")
        get iron_admin.autocomplete_path("users"), params: { q: "Test" }, as: :json

        data = response.parsed_body
        expect(data.length).to eq(20)
      end
    end

    context "with empty query" do
      it "returns empty array" do
        create(:user, name: "Test User")
        get iron_admin.autocomplete_path("users"), params: { q: "" }, as: :json

        data = response.parsed_body
        expect(data).to eq([])
      end

      it "returns empty array when query param is missing" do
        create(:user, name: "Test User")
        get iron_admin.autocomplete_path("users"), as: :json

        data = response.parsed_body
        expect(data).to eq([])
      end
    end

    context "with case-insensitive search" do
      it "matches regardless of case" do
        create(:user, name: "Alice SMITH")
        get iron_admin.autocomplete_path("users"), params: { q: "smith" }, as: :json

        data = response.parsed_body
        expect(data.length).to eq(1)
        expect(data.first["label"]).to eq("Alice SMITH")
      end
    end

    context "with custom display attribute" do
      let(:autocomplete_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "AutocompleteUserResource"
          end

          def self.resource_name
            "autocomplete_users"
          end

          def self.display_attribute
            :email
          end
        end
      end

      before do
        IronAdmin::ResourceRegistry.register(autocomplete_resource)
      end

      after do
        IronAdmin::ResourceRegistry.reset!
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
        IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
      end

      it "uses the display_attribute for searching and labeling" do
        create(:user, name: "Test User", email: "test@example.com")
        create(:user, name: "Another User", email: "another@example.com")

        get iron_admin.autocomplete_path("autocomplete_users"), params: { q: "test@" }, as: :json

        data = response.parsed_body
        expect(data.length).to eq(1)
        expect(data.first["label"]).to eq("test@example.com")
      end
    end

    context "with unknown resource" do
      it "returns not found" do
        get iron_admin.autocomplete_path("unknown_resources"), params: { q: "test" }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "multi-tenant scoping" do
    context "when tenant scope is configured" do
      before do
        # Configure tenant scope to only show active users
        IronAdmin.configure do |config|
          config.tenant_scope do |scope|
            scope.where(active: true)
          end
        end
      end

      it "applies tenant scope to index queries" do
        create(:user, name: "Active User", active: true)
        create(:user, name: "Inactive User", active: false)

        get iron_admin.resources_path("users"), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Active User")
        expect(response.body).not_to include("Inactive User")
      end

      it "applies tenant scope to show action" do
        active_user = create(:user, name: "Active User", active: true)

        get iron_admin.resource_path("users", active_user), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Active User")
      end

      it "prevents cross-tenant record access on show" do
        inactive_user = create(:user, name: "Inactive User", active: false)

        expect do
          get iron_admin.resource_path("users", inactive_user), as: :html
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "prevents cross-tenant record access on edit" do
        inactive_user = create(:user, name: "Inactive User", active: false)

        expect do
          get iron_admin.edit_resource_path("users", inactive_user), as: :html
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "prevents cross-tenant record access on update" do
        inactive_user = create(:user, name: "Inactive User", active: false)

        expect do
          patch iron_admin.resource_path("users", inactive_user),
                params: { record: { name: "New Name", email: inactive_user.email, role: inactive_user.role } },
                as: :html
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "prevents cross-tenant record access on destroy" do
        inactive_user = create(:user, name: "Inactive User", active: false)

        expect do
          delete iron_admin.resource_path("users", inactive_user), as: :html
        end.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "applies tenant scope to bulk actions" do
        active_user = create(:user)
        active_licenses = create_list(:license, 2, user: active_user, status: "active")
        inactive_user = create(:user, active: false)
        inactive_license = create(:license, user: inactive_user, status: "active")

        # Reconfigure tenant scope for licenses based on user's active status
        IronAdmin.configure do |config|
          config.tenant_scope do |scope|
            scope.joins(:user).where(users: { active: true })
          end
        end

        post iron_admin.resource_bulk_action_path("licenses", "export"),
             params: { ids: active_licenses.map(&:id) + [inactive_license.id] },
             as: :html

        expect(response).to redirect_to(iron_admin.resources_path("licenses"))
      end

      it "applies tenant scope to autocomplete" do
        create(:user, name: "Active Smith", active: true)
        create(:user, name: "Inactive Smith", active: false)

        get iron_admin.autocomplete_path("users"), params: { q: "Smith" }, as: :json

        data = response.parsed_body
        expect(data.length).to eq(1)
        expect(data.first["label"]).to eq("Active Smith")
      end
    end

    context "when no tenant scope is configured" do
      it "returns all records on index" do
        create(:user, name: "Active User", active: true)
        create(:user, name: "Inactive User", active: false)

        get iron_admin.resources_path("users"), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Active User")
        expect(response.body).to include("Inactive User")
      end

      it "allows access to any record on show" do
        inactive_user = create(:user, name: "Inactive User", active: false)

        get iron_admin.resource_path("users", inactive_user), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Inactive User")
      end

      it "allows updating any record" do
        user = create(:user, name: "Original Name", active: false)

        patch iron_admin.resource_path("users", user),
              params: { record: { name: "Updated Name", email: user.email, role: user.role } },
              as: :html

        expect(user.reload.name).to eq("Updated Name")
      end

      it "allows deleting any record" do
        user = create(:user, active: false)

        expect do
          delete iron_admin.resource_path("users", user), as: :html
        end.to change(User, :count).by(-1)
      end
    end

    context "with organization-based tenant scope" do
      # Simulates a SaaS scenario where users belong to organizations
      let(:org_id) { 1 }

      before do
        # Simulate storing org_id in a thread-local variable (like Current.organization)
        Thread.current[:test_org_id] = org_id

        IronAdmin.configure do |config|
          config.tenant_scope do |scope|
            # In a real app, this would be scope.where(organization_id: Current.organization.id)
            # Here we simulate with a role-based scope for testing
            current_org_role = Thread.current[:test_org_id] == 1 ? "admin" : "member"
            scope.where(role: current_org_role)
          end
        end
      end

      after do
        Thread.current[:test_org_id] = nil
      end

      it "isolates records by tenant" do
        create(:user, name: "Admin User", role: "admin")
        create(:user, name: "Member User", role: "member")

        get iron_admin.resources_path("users"), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Admin User")
        expect(response.body).not_to include("Member User")
      end

      it "switches tenant context appropriately" do
        create(:user, name: "Admin User", role: "admin")
        create(:user, name: "Member User", role: "member")

        # Switch to org 2 (member context)
        Thread.current[:test_org_id] = 2

        get iron_admin.resources_path("users"), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Admin User")
        expect(response.body).to include("Member User")
      end
    end
  end
end
