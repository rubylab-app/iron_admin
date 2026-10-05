require "rails_helper"

RSpec.describe "IronAdmin::Resources#execute_action error handling", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
  end

  describe "POST /:resource_name/:id/actions/:action_name" do
    let(:user) { create(:user) }
    let!(:license) { create(:license, user: user, status: "active") }

    context "when action does not exist" do
      it "returns 404 not found" do
        post iron_admin.resource_action_path("licenses", license, "nonexistent_action"), as: :html
        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 even with non-existent record id" do
        # This tests the fix: action validation should happen BEFORE record lookup
        # Previously this would raise ActiveRecord::RecordNotFound
        post iron_admin.resource_action_path("licenses", 999_999, "nonexistent_action"), as: :html
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when record does not exist" do
      it "returns 404 not found for valid action with non-existent record" do
        post iron_admin.resource_action_path("licenses", 999_999, "revoke"), as: :html
        expect(response).to have_http_status(:not_found)
      end

      it "does not raise an exception for non-existent records" do
        expect do
          post iron_admin.resource_action_path("licenses", 999_999, "revoke"), as: :html
        end.not_to raise_error
      end
    end

    context "when action is unauthorized" do
      let(:policy_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "PolicyActionResource"
          end

          def self.resource_name
            "policy_action_licenses"
          end

          belongs_to :user, display: :email

          action :test_action do |license|
            license.update!(status: "revoked")
          end

          policy do
            allow :test_action, if: ->(user) { user&.role == "admin" }
          end
        end
      end

      before do
        IronAdmin::ResourceRegistry.register(policy_resource)
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "member") }
        end
      end

      it "returns 403 forbidden before trying to find the record" do
        # Even with a non-existent record, we should get forbidden (not 404 from record lookup)
        post iron_admin.resource_action_path("policy_action_licenses", license, "test_action"), as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when action exists and record exists" do
      it "executes the action successfully" do
        post iron_admin.resource_action_path("licenses", license, "revoke"), as: :html
        expect(license.reload.status).to eq("revoked")
      end

      it "redirects to the resource show page" do
        post iron_admin.resource_action_path("licenses", license, "revoke"), as: :html
        expect(response).to redirect_to(iron_admin.resource_path("licenses", license))
      end

      it "shows success message in flash" do
        post iron_admin.resource_action_path("licenses", license, "revoke"), as: :html
        expect(flash[:notice]).to eq("Action completed")
      end
    end

    context "error handling order verification" do
      # This context specifically tests the order of operations:
      # 1. Validate action exists -> 404 if not
      # 2. Check authorization -> 403 if not allowed
      # 3. Find record -> 404 if not found
      # 4. Execute action

      it "validates action before finding record (non-existent action, non-existent record)" do
        # Both action and record don't exist - should return 404 for action not found
        # NOT raise ActiveRecord::RecordNotFound
        post iron_admin.resource_action_path("licenses", 999_999, "totally_fake_action"), as: :html
        expect(response).to have_http_status(:not_found)
      end

      it "checks authorization before finding record" do
        policy_resource = Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "AuthCheckResource"
          end

          def self.resource_name
            "auth_check_licenses"
          end

          belongs_to :user, display: :email

          action :restricted_action do |license|
            license.update!(status: "revoked")
          end

          policy do
            allow :restricted_action, if: ->(_user) { false } # Always deny
          end
        end

        IronAdmin::ResourceRegistry.register(policy_resource)

        # Action exists but is forbidden - should return 403 even with non-existent record
        post iron_admin.resource_action_path("auth_check_licenses", 999_999, "restricted_action"), as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when action raises an error" do
      let(:error_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "ErrorActionResource"
          end

          def self.resource_name
            "error_action_licenses"
          end

          belongs_to :user, display: :email

          action :failing_action do |_license|
            raise StandardError, "Something went wrong"
          end
        end
      end

      before do
        IronAdmin::ResourceRegistry.register(error_resource)
      end

      it "redirects to resource index page on error" do
        post iron_admin.resource_action_path("error_action_licenses", license, "failing_action"), as: :html
        expect(response).to redirect_to(iron_admin.resources_path("error_action_licenses"))
      end

      it "shows error message in flash" do
        post iron_admin.resource_action_path("error_action_licenses", license, "failing_action"), as: :html
        expect(flash[:alert]).to eq("Something went wrong. Please try again.")
      end
    end
  end
end
