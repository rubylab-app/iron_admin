# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bulk actions the policy denies", type: :request do
  let!(:license) { create(:license) }

  def register_bulk_policy_resource(form_fields: [], denied: [])
    resource = Class.new(IronAdmin::Resource) do
      self.model_class_override = License

      define_singleton_method(:name) { "IronAdmin::Resources::BulkPolicyLicenseResource" }
      define_singleton_method(:resource_name) { "bulk_policy_licenses" }

      bulk_action(:export, form_fields: form_fields) { |licenses| licenses.pluck(:id) }
      bulk_action(:archive, form_fields: form_fields) { |licenses| licenses.update_all(status: :expired) }

      policy do
        allow :read
        denied.each { |name| deny name }
      end
    end
    IronAdmin::ResourceRegistry.register(resource)
  end

  def index_document(denied: [], form_fields: [])
    register_bulk_policy_resource(form_fields: form_fields, denied: denied)
    get iron_admin.resources_path("bulk_policy_licenses"), as: :html
    response.parsed_body
  end

  def bulk_button_labels(document)
    document.css("#bulk-actions-form button").map { |button| button.text.squish }
  end

  context "without form fields" do
    it "shows every allowed action and the checkbox column" do
      document = index_document

      expect(bulk_button_labels(document)).to eq(%w[Export Archive])
      expect(document.css("input[name='ids[]']")).not_to be_empty
    end

    it "renders no bulk bar and no checkbox column when every action is denied" do
      document = index_document(denied: %i[export archive])

      expect(document.css("[data-cp-bulk-select-target='bar']")).to be_empty
      expect(document.css("input[name='ids[]']")).to be_empty
      expect(document.css("[data-cp-bulk-select-target='selectAll']")).to be_empty
    end

    it "shows only the action the policy allows" do
      document = index_document(denied: [:archive])

      expect(bulk_button_labels(document)).to eq(["Export"])
      expect(document.css("input[name='ids[]']")).not_to be_empty
    end
  end

  context "with form fields" do
    let(:form_fields) { [{ name: :reason }] }

    it "shows every allowed action and the checkbox column" do
      document = index_document(form_fields: form_fields)
      buttons = document.css("#bulk-actions-form button")

      expect(bulk_button_labels(document)).to eq(%w[Export Archive])
      expect(buttons.pluck("formmethod")).to eq(%w[get get])
      expect(document.css("input[name='ids[]']")).not_to be_empty
    end

    it "renders no bulk bar and no checkbox column when every action is denied" do
      document = index_document(form_fields: form_fields, denied: %i[export archive])

      expect(document.css("[data-cp-bulk-select-target='bar']")).to be_empty
      expect(document.css("input[name='ids[]']")).to be_empty
      expect(document.css("[data-cp-bulk-select-target='selectAll']")).to be_empty
    end

    it "shows only the action the policy allows" do
      document = index_document(form_fields: form_fields, denied: [:archive])
      buttons = document.css("#bulk-actions-form button")

      expect(bulk_button_labels(document)).to eq(["Export"])
      expect(buttons.pluck("formaction")).to eq(
        [iron_admin.resource_bulk_action_form_path("bulk_policy_licenses", "export")]
      )
      expect(buttons.pluck("formmethod")).to eq(["get"])
      expect(document.css("input[name='ids[]']")).not_to be_empty
    end
  end

  context "when a bulk action condition raises for a nil user" do
    def register_raising_bulk_resource
      IronAdmin.configure { |config| config.current_user { nil } }

      resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        define_singleton_method(:name) { "IronAdmin::Resources::RaisingBulkLicenseResource" }
        define_singleton_method(:resource_name) { "raising_bulk_licenses" }

        bulk_action(:export) { |licenses| licenses.pluck(:id) }
        bulk_action(:archive) { |licenses| licenses.update_all(status: :expired) }

        policy do
          allow :read
          allow :archive, if: ->(user) { user.admin? }
        end
      end
      IronAdmin::ResourceRegistry.register(resource)
    end

    it "returns 200" do
      register_raising_bulk_resource

      get iron_admin.resources_path("raising_bulk_licenses"), as: :html

      expect(response).to have_http_status(:ok)
    end

    it "hides the action whose condition raises" do
      register_raising_bulk_resource
      get iron_admin.resources_path("raising_bulk_licenses"), as: :html

      expect(bulk_button_labels(response.parsed_body)).to eq(["Export"])
    end

    it "logs the condition's error" do
      register_raising_bulk_resource
      allow(Rails.logger).to receive(:error)

      get iron_admin.resources_path("raising_bulk_licenses"), as: :html

      expect(Rails.logger).to have_received(:error).with(
        a_string_matching(/\[IronAdmin\] NoMethodError:.*admin\?.*for nil/)
      )
    end

    it "redirects a post of the raising action to the index" do
      register_raising_bulk_resource

      post iron_admin.resource_bulk_action_path("raising_bulk_licenses", "archive"),
           params: { ids: [license.id] },
           as: :html

      expect(response).to redirect_to(iron_admin.resources_path("raising_bulk_licenses"))
    end

    it "leaves the record unchanged when the condition raises" do
      register_raising_bulk_resource

      post iron_admin.resource_bulk_action_path("raising_bulk_licenses", "archive"),
           params: { ids: [license.id] },
           as: :html

      expect(license.reload.status).to eq("active")
    end
  end

  context "with a custom table and every bulk action denied" do
    before do
      resource = register_bulk_policy_resource(denied: %i[export archive])
      resource.component :table, checkbox_table_component
      get iron_admin.resources_path("bulk_policy_licenses"), as: :html
    end

    def checkbox_table_component
      component = Class.new(ViewComponent::Base) do
        def initialize(records:, bulk_actions:)
          super()
          @records = records
          @bulk_actions = bulk_actions
        end

        def call
          boxes = if Array(@bulk_actions).any?
                    safe_join(@records.map { |record| tag.input(type: "checkbox", name: "ids[]", value: record.id) })
                  else
                    ""
                  end
          tag.div(boxes, id: "custom-table")
        end
      end
      stub_const("DeniedBulkActionsTable", component)
    end

    it "renders the custom table" do
      expect(response.parsed_body.at_css("#custom-table")).to be_present
    end

    it "renders no row checkbox" do
      expect(response.parsed_body.at_css("#custom-table input[name='ids[]']")).to be_nil
    end
  end

  it "still returns 403 when a denied bulk action is posted" do
    register_bulk_policy_resource(denied: [:archive])

    post iron_admin.resource_bulk_action_path("bulk_policy_licenses", "archive"),
         params: { ids: [license.id] },
         as: :html

    expect(response).to have_http_status(:forbidden)
  end
end
