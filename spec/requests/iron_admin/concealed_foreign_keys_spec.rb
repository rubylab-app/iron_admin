# frozen_string_literal: true

require "rails_helper"

# A concealed belongs_to is named for the association, but sort, audit and
# filters must also cover its foreign key.
RSpec.describe "Concealed foreign keys", type: :request do
  describe "index sort" do
    subject(:license_keys) do
      response.parsed_body.css("tbody tr").filter_map { |row| row.text[/LIC-(?:OLD|NEW)/] }
    end

    let(:sort_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "ConcealedFkSortLicenseResource"
        end

        def self.resource_name
          "concealed_fk_sort_licenses"
        end

        field :user, visible: false
        index_fields :license_key
      end
    end

    # user A is inserted before user B, so user_id asc is LIC-NEW, LIC-OLD.
    # LIC-OLD is the older row. Rejecting the sort column keeps direction, so
    # the fallback is created_at asc: LIC-OLD, LIC-NEW.
    before do
      IronAdmin::ResourceRegistry.register(sort_resource)
      user_a = create(:user)
      user_b = create(:user)
      create(:license, user: user_b, license_key: "LIC-OLD", created_at: 2.days.ago)
      create(:license, user: user_a, license_key: "LIC-NEW", created_at: 1.day.ago)
      get iron_admin.resources_path("concealed_fk_sort_licenses"),
          params: { sort: "user_id", direction: "asc" }, as: :html
    end

    it "falls back to the default sort column" do
      expect(license_keys).to eq(%w[LIC-OLD LIC-NEW])
    end
  end

  describe "audit of a concealed belongs_to" do
    let(:audit_resource) do
      other_id = create(:user).id

      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "ConcealedFkAuditLicenseResource"
        end

        def self.resource_name
          "concealed_fk_audit_licenses"
        end

        field :user, visible: false

        action :reassign do |license|
          license.update!(user_id: other_id)
        end
      end
    end

    before do
      IronAdmin.configure { |c| c.audit_enabled = true }
      IronAdmin::ResourceRegistry.register(audit_resource)
    end

    it "filters the foreign key in the audit changes" do
      license = create(:license, user: create(:user))

      post iron_admin.resource_action_path("concealed_fk_audit_licenses", license, "reassign"), as: :html

      expect(IronAdmin::AuditLog.entries.last.changes["user_id"]).to eq("[FILTERED]")
    end
  end

  describe "audit of a concealed foreign key override" do
    let(:audit_resource) do
      other_id = create(:user).id

      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "ConcealedFkColumnAuditLicenseResource"
        end

        def self.resource_name
          "concealed_fk_column_audit_licenses"
        end

        field :user_id, visible: false

        action :reassign do |license|
          license.update!(user_id: other_id)
        end
      end
    end

    before do
      IronAdmin.configure { |c| c.audit_enabled = true }
      IronAdmin::ResourceRegistry.register(audit_resource)
    end

    it "filters the foreign key when the override uses the column name" do
      license = create(:license, user: create(:user))

      post iron_admin.resource_action_path("concealed_fk_column_audit_licenses", license, "reassign"), as: :html

      expect(IronAdmin::AuditLog.entries.last.changes["user_id"]).to eq("[FILTERED]")
    end
  end

  # Numeric *_id columns are not auto-inferred. A never-visible belongs_to
  # still has to drop its foreign key via sensitive_field_names.
  describe "auto-inferred filters" do
    subject(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "ConcealedFkInferredLicenseResource"
        end

        def self.resource_name
          "concealed_fk_inferred_licenses"
        end

        field :user, visible: false
      end
    end

    it "drops the foreign key when the belongs_to is never visible" do
      dropped = resource.send(:sensitive_field_names).map(&:to_sym)
      names = resource.auto_inferred_filters.pluck(:name).map(&:to_sym)

      expect(dropped).to include(:user_id)
      expect(names).not_to include(:user_id)
    end
  end
end
