require "rails_helper"
require_relative "../../support/test_resources"

RSpec.describe IronAdmin::Resource do
  describe "model inference" do
    it "infers model from class name" do
      expect(TestUserResource.model).to eq(User)
    end

    it "infers model for TestLicenseResource" do
      expect(TestLicenseResource.model).to eq(License)
    end
  end

  describe ".adapter" do
    it "returns an ActiveRecord adapter instance" do
      adapter = TestUserResource.adapter
      expect(adapter).to be_a(IronAdmin::Adapters::ActiveRecord)
    end

    it "wraps the resource's model" do
      adapter = TestUserResource.adapter
      expect(adapter.model_class).to eq(User)
    end

    it "memoizes the adapter" do
      adapter1 = TestUserResource.adapter
      adapter2 = TestUserResource.adapter
      expect(adapter1).to equal(adapter2)
    end
  end

  describe ".adapter_class" do
    it "defaults to :active_record symbol" do
      expect(TestUserResource.adapter_class).to eq(:active_record)
    end

    it "can be overridden per resource" do
      custom_adapter = Class.new(IronAdmin::Adapters::Base)
      resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = User
        self.adapter_class = custom_adapter

        def self.name
          "CustomAdapterResource"
        end
      end
      expect(resource.adapter_class).to eq(custom_adapter)
    end
  end

  describe "field overrides" do
    it "merges overrides with inferred fields" do
      fields = TestLicenseResource.resolved_fields
      license_key = fields.find { |f| f.name == :license_key }

      expect(license_key.readonly).to be(true)
    end

    it "uses inferred fields when no override" do
      fields = TestUserResource.resolved_fields
      expect(fields).not_to be_empty
    end
  end

  describe "searchable" do
    it "uses custom searchable columns" do
      expect(TestLicenseResource.searchable_columns).to eq([:license_key])
    end

    it "defaults to string/text columns" do
      columns = TestUserResource.searchable_columns
      expect(columns).to include(:email)
      expect(columns).to include(:name)
    end
  end

  describe "unsearchable" do
    let(:resource_with_unsearchable) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "UnsearchableTestResource"
        end

        unsearchable :email
      end
    end

    it "excludes specified columns from searchable columns" do
      columns = resource_with_unsearchable.searchable_columns
      expect(columns).not_to include(:email)
      expect(columns).to include(:name)
    end

    it "can exclude multiple columns" do
      resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "MultiUnsearchableResource"
        end

        unsearchable :email, :name
      end

      columns = resource.searchable_columns
      expect(columns).not_to include(:email)
      expect(columns).not_to include(:name)
    end

    it "converts strings to symbols" do
      resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "StringUnsearchableResource"
        end

        unsearchable "email"
      end

      columns = resource.searchable_columns
      expect(columns).not_to include(:email)
    end

    it "still excludes digest columns" do
      resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "DigestExclusionResource"
        end
      end

      columns = resource.searchable_columns
      expect(columns.any? { |c| c.to_s.end_with?("_digest") }).to be false
    end

    it "does not affect explicit searchable columns" do
      resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "ExplicitSearchableResource"
        end

        searchable :email, :name
        unsearchable :email
      end

      # When explicit searchable is set, unsearchable is ignored
      columns = resource.searchable_columns
      expect(columns).to eq(%i[email name])
    end
  end

  describe "filters" do
    it "stores custom filters" do
      filters = TestLicenseResource.defined_filters
      expect(filters.length).to eq(2)
      expect(filters.first[:name]).to eq(:status)
    end
  end

  describe "scopes" do
    it "stores named scopes" do
      scopes = TestLicenseResource.defined_scopes
      expect(scopes.length).to eq(2)
      expect(scopes.first[:name]).to eq(:active)
      expect(scopes.first[:default]).to be(true)
    end
  end

  describe "actions" do
    it "stores custom actions" do
      actions = TestLicenseResource.defined_actions
      expect(actions.length).to eq(1)
      expect(actions.first[:name]).to eq(:revoke)
      expect(actions.first[:confirm]).to be(true)
    end

    it "defaults form_fields to empty array" do
      action = TestLicenseResource.defined_actions.first
      expect(action[:form_fields]).to eq([])
    end
  end

  describe "actions with form_fields" do
    let(:resource_with_form_action) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "FormActionResource"
        end

        action :suspend_with_reason,
               icon: "pause",
               form_fields: [
                 action_field(:reason, type: :textarea, required: true, label: "Suspension Reason"),
                 action_field(:duration_days, type: :number, label: "Duration (days)"),
                 action_field(:notify_user, type: :boolean, label: "Send notification"),
               ] do |_license, _params|
          # noop
        end
      end
    end

    it "stores form_fields as ActionField instances" do
      action = resource_with_form_action.defined_actions.find { |a| a[:name] == :suspend_with_reason }
      expect(action[:form_fields]).to all(be_a(IronAdmin::ActionField))
    end

    it "stores the correct number of form fields" do
      action = resource_with_form_action.defined_actions.find { |a| a[:name] == :suspend_with_reason }
      expect(action[:form_fields].length).to eq(3)
    end

    it "preserves field attributes" do
      action = resource_with_form_action.defined_actions.find { |a| a[:name] == :suspend_with_reason }
      reason_field = action[:form_fields].first
      expect(reason_field.name).to eq(:reason)
      expect(reason_field.type).to eq(:textarea)
      expect(reason_field.required).to be(true)
      expect(reason_field.label).to eq("Suspension Reason")
    end

    it "preserves other action options" do
      action = resource_with_form_action.defined_actions.find { |a| a[:name] == :suspend_with_reason }
      expect(action[:icon]).to eq("pause")
    end

    context "with hash form_fields instead of ActionField instances" do
      let(:resource_with_hash_fields) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "HashFieldResource"
          end

          action :test_action,
                 form_fields: [
                   { name: :reason, type: :textarea, required: true },
                 ] do |_license, _params|
            # noop
          end
        end
      end

      it "coerces hashes into ActionField instances" do
        action = resource_with_hash_fields.defined_actions.find { |a| a[:name] == :test_action }
        expect(action[:form_fields].first).to be_a(IronAdmin::ActionField)
        expect(action[:form_fields].first.name).to eq(:reason)
      end
    end
  end

  describe ".action_field" do
    it "returns an ActionField instance" do
      field = described_class.action_field(:reason, type: :textarea, required: true)
      expect(field).to be_a(IronAdmin::ActionField)
    end

    it "passes arguments to ActionField.new" do
      field = described_class.action_field(:duration, type: :number, label: "Days")
      expect(field.name).to eq(:duration)
      expect(field.type).to eq(:number)
      expect(field.label).to eq("Days")
    end
  end

  describe "bulk actions" do
    it "stores bulk actions" do
      expect(TestLicenseResource.defined_bulk_actions.length).to eq(1)
      expect(TestLicenseResource.defined_bulk_actions.first[:name]).to eq(:export)
    end

    it "defaults form_fields to empty array" do
      action = TestLicenseResource.defined_bulk_actions.first
      expect(action[:form_fields]).to eq([])
    end
  end

  describe "bulk actions with form_fields" do
    let(:resource_with_bulk_form) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = License

        def self.name
          "BulkFormResource"
        end

        bulk_action :bulk_revoke_with_note,
                    icon: "x-circle",
                    form_fields: [
                      action_field(:note, type: :textarea, required: true, label: "Revocation Note"),
                    ] do |_licenses, _params|
          # noop
        end
      end
    end

    it "stores form_fields as ActionField instances" do
      action = resource_with_bulk_form.defined_bulk_actions.first
      expect(action[:form_fields]).to all(be_a(IronAdmin::ActionField))
    end

    it "preserves field attributes" do
      action = resource_with_bulk_form.defined_bulk_actions.first
      note_field = action[:form_fields].first
      expect(note_field.name).to eq(:note)
      expect(note_field.type).to eq(:textarea)
      expect(note_field.label).to eq("Revocation Note")
    end
  end

  describe "view field lists" do
    it "stores index fields" do
      expect(TestLicenseResource.index_field_names).to eq(%i[license_key status expires_at])
    end

    it "stores form fields" do
      expect(TestLicenseResource.form_field_names).to eq(%i[license_type status max_devices])
    end

    it "defaults to all fields" do
      expect(TestUserResource.index_field_names).to be_nil
    end
  end

  describe "associations" do
    it "stores belongs_to declarations" do
      assoc = TestLicenseResource.defined_associations[:user]
      expect(assoc[:kind]).to eq(:belongs_to)
      expect(assoc[:display]).to eq(:email)
    end

    it "stores has_many declarations" do
      assoc = TestUserResource.defined_associations[:licenses]
      expect(assoc[:kind]).to eq(:has_many)
    end

    it "stores has_one declarations" do
      assoc = TestUserResource.defined_associations[:profile]
      expect(assoc[:kind]).to eq(:has_one)
    end

    it "resolves has_many associations with resource and reflection" do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(TestUserResource)
      IronAdmin::ResourceRegistry.register(TestLicenseResource)

      associations = TestUserResource.has_many_associations
      licenses_assoc = associations.find { |a| a[:name] == :licenses }
      expect(licenses_assoc).to be_present
      expect(licenses_assoc[:resource]).to eq(TestLicenseResource)
    end

    it "resolves has_many associations when resource is a string" do
      resource_class = Class.new(IronAdmin::Resource) do
        self.model_class_override = User
        has_many :licenses, resource: "IronAdmin::Resources::LicenseResource"
      end

      associations = resource_class.has_many_associations
      licenses_assoc = associations.find { |a| a[:name] == :licenses }
      expect(licenses_assoc).to be_present
      expect(licenses_assoc[:resource]).to eq(IronAdmin::Resources::LicenseResource)
    end

    it "resolves has_many associations when resource is a class" do
      resource_class = Class.new(IronAdmin::Resource) do
        self.model_class_override = User
        has_many :licenses, resource: IronAdmin::Resources::LicenseResource
      end

      associations = resource_class.has_many_associations
      licenses_assoc = associations.find { |a| a[:name] == :licenses }
      expect(licenses_assoc).to be_present
      expect(licenses_assoc[:resource]).to eq(IronAdmin::Resources::LicenseResource)
    end

    it "resolves has_one associations with resource and reflection" do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(TestUserResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::ProfileResource)

      associations = TestUserResource.has_one_associations
      profile_assoc = associations.find { |a| a[:name] == :profile }
      expect(profile_assoc).to be_present
      expect(profile_assoc[:resource]).to eq(IronAdmin::Resources::ProfileResource)
    end

    it "resolves has_one associations when resource is a string" do
      resource_class = Class.new(IronAdmin::Resource) do
        self.model_class_override = User
        has_one :profile, resource: "IronAdmin::Resources::ProfileResource"
      end

      associations = resource_class.has_one_associations
      profile_assoc = associations.find { |a| a[:name] == :profile }
      expect(profile_assoc).to be_present
      expect(profile_assoc[:resource]).to eq(IronAdmin::Resources::ProfileResource)
    end

    it "returns empty for has_one when no associations defined" do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(TestLicenseResource)

      expect(TestLicenseResource.has_one_associations).to eq([])
    end

    it "stores has_and_belongs_to_many declarations" do
      assoc = IronAdmin::Resources::PostResource.defined_associations[:tags]
      expect(assoc[:kind]).to eq(:has_and_belongs_to_many)
    end

    it "resolves habtm associations when resource is a string" do
      resource_class = Class.new(IronAdmin::Resource) do
        self.model_class_override = Post
        has_and_belongs_to_many :tags, resource: "IronAdmin::Resources::TagResource"
      end

      associations = resource_class.habtm_associations
      tags_assoc = associations.find { |a| a[:name] == :tags }
      expect(tags_assoc).to be_present
      expect(tags_assoc[:resource]).to eq(IronAdmin::Resources::TagResource)
    end

    it "resolves habtm associations with reflection" do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::TagResource)

      associations = IronAdmin::Resources::PostResource.habtm_associations
      tags_assoc = associations.find { |a| a[:name] == :tags }
      expect(tags_assoc).to be_present
      expect(tags_assoc[:resource]).to eq(IronAdmin::Resources::TagResource)
    end

    it "returns empty for habtm when no associations defined" do
      IronAdmin::ResourceRegistry.reset!
      IronAdmin::ResourceRegistry.register(TestUserResource)

      expect(TestUserResource.habtm_associations).to eq([])
    end

    it "infers belongs_to fields from model" do
      fields = TestLicenseResource.resolved_fields
      user_field = fields.find { |f| f.name == :user }
      expect(user_field).to be_present
      expect(user_field.type).to eq(:belongs_to)
      expect(user_field.options[:foreign_key]).to eq(:user_id)
      expect(user_field.options[:association_class]).to eq(User)
    end

    it "applies display override from DSL to inferred field" do
      fields = TestLicenseResource.resolved_fields
      user_field = fields.find { |f| f.name == :user }
      expect(user_field.options[:display]).to eq(:email)
    end

    it "excludes raw foreign key columns for belongs_to associations" do
      fields = TestLicenseResource.resolved_fields
      expect(fields.map(&:name)).not_to include(:user_id)
    end
  end

  describe "menu" do
    it "stores menu options" do
      expect(TestLicenseResource.menu_options).to eq({ priority: 1, icon: "key", group: "Licensing" })
    end

    it "stores priority in menu options" do
      expect(TestUserResource.menu_options[:priority]).to eq(0)
    end

    it "accepts :section as a backward-compatible alias for :group" do
      legacy_resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = User
        menu icon: "key", section: "Legacy"
      end
      expect(legacy_resource.menu_options[:group]).to eq("Legacy")
    end

    it "prefers :group when both :group and :section are passed" do
      mixed_resource = Class.new(IronAdmin::Resource) do
        self.model_class_override = User
        menu group: "Primary", section: "Legacy"
      end
      expect(mixed_resource.menu_options[:group]).to eq("Primary")
      expect(mixed_resource.menu_options).not_to have_key(:section)
    end
  end

  describe ".resource_policy" do
    context "when policy block is defined" do
      let(:resource_with_policy) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "PolicyTestResource"
          end

          policy do
            allow :create
          end
        end
      end

      after do
        resource_with_policy.reset_resource_policy!
      end

      it "returns a Policy instance" do
        expect(resource_with_policy.resource_policy).to be_a(IronAdmin::Policy)
      end

      it "caches the policy instance" do
        first_call = resource_with_policy.resource_policy
        second_call = resource_with_policy.resource_policy

        expect(first_call).to be(second_call)
      end
    end

    context "when no policy block is defined" do
      let(:resource_without_policy) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "NoPolicyTestResource"
          end
        end
      end

      it "returns nil" do
        expect(resource_without_policy.resource_policy).to be_nil
      end
    end
  end

  describe "preload_associations" do
    context "when no explicit preload is defined" do
      it "infers belongs_to associations from resolved fields" do
        preloads = TestLicenseResource.preload_associations
        expect(preloads).to include(:user)
      end

      it "returns empty array when no belongs_to associations exist" do
        expect(TestUserResource.preload_associations).to eq([])
      end
    end

    context "when explicit preload is defined" do
      let(:custom_preload_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "CustomPreloadResource"
          end

          belongs_to :user, display: :email
          preload :user, :some_other_association
        end
      end

      it "uses the explicitly defined associations" do
        expect(custom_preload_resource.preload_associations).to eq(%i[user some_other_association])
      end

      it "overrides the auto-inferred associations" do
        # Even though user would be inferred, explicit preload takes precedence
        expect(custom_preload_resource.preload_associations).not_to eq([:user])
        expect(custom_preload_resource.preload_associations.length).to eq(2)
      end
    end

    context "with multiple belongs_to associations" do
      let(:multi_belongs_to_resource) do
        # Create a resource that would have multiple belongs_to if the model supported it
        # For now, test with the existing License which has user
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "MultiBelongsToResource"
          end

          belongs_to :user, display: :email
        end
      end

      it "returns all belongs_to associations" do
        preloads = multi_belongs_to_resource.preload_associations
        expect(preloads).to include(:user)
      end
    end
  end

  describe ".auto_inferred_filters" do
    context "when model has enums" do
      it "generates select filter for each enum" do
        filters = TestLicenseResource.auto_inferred_filters
        status_filter = filters.find { |f| f[:name] == :status }

        expect(status_filter).to be_present
        expect(status_filter[:type]).to eq(:select)
      end

      it "includes enum values as options" do
        filters = TestLicenseResource.auto_inferred_filters
        status_filter = filters.find { |f| f[:name] == :status }

        expect(status_filter[:options]).to eq(%w[active expired revoked])
      end
    end

    context "when model has no enums" do
      it "does not include any :select filters" do
        select_filters = TestUserResource.auto_inferred_filters.select { |f| f[:type] == :select }
        expect(select_filters).to be_empty
      end
    end

    context "with string/text column inference" do
      it "infers :string filter for string columns" do
        filters = TestUserResource.auto_inferred_filters
        name_filter = filters.find { |f| f[:name] == :name }

        expect(name_filter).to be_present
        expect(name_filter[:type]).to eq(:string)
      end

      it "sets a humanized label" do
        filters = TestUserResource.auto_inferred_filters
        name_filter = filters.find { |f| f[:name] == :name }

        expect(name_filter[:label]).to eq("Name")
      end

      it "skips id, created_at, and updated_at columns" do
        filter_names = TestUserResource.auto_inferred_filters.pluck(:name)

        expect(filter_names).not_to include(:id)
        expect(filter_names).not_to include(:created_at)
        expect(filter_names).not_to include(:updated_at)
      end
    end

    context "with integer/float/decimal column inference" do
      it "infers :number filter for integer columns" do
        filters = TestLicenseResource.auto_inferred_filters
        max_devices_filter = filters.find { |f| f[:name] == :max_devices }

        expect(max_devices_filter).to be_present
        expect(max_devices_filter[:type]).to eq(:number)
      end

      it "skips foreign key columns ending in _id" do
        filter_names = TestLicenseResource.auto_inferred_filters.pluck(:name)

        expect(filter_names).not_to include(:user_id)
      end
    end

    context "when columns overlap with defined or enum filters" do
      it "does not duplicate already-defined filter columns" do
        resource = Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "NoDuplicateFilterResource"
          end

          filter :name, type: :string, label: "Custom Name"
        end

        inferred_name = resource.auto_inferred_filters.select { |f| f[:name] == :name }
        expect(inferred_name).to be_empty
      end

      it "does not duplicate enum-inferred filter columns" do
        all_status = TestLicenseResource.auto_inferred_filters.select { |f| f[:name] == :status }

        expect(all_status.length).to eq(1)
        expect(all_status.first[:type]).to eq(:select)
      end
    end

    context "when model does not respond to defined_enums" do
      let(:resource_with_non_enum_model) do
        model_double = Class.new do
          def self.columns
            []
          end

          def self.column_names
            []
          end

          def self.model_name
            OpenStruct.new(plural: "non_enums", human: "Non Enum")
          end
        end

        Class.new(IronAdmin::Resource) do
          self.model_class_override = model_double

          def self.name
            "NonEnumModelResource"
          end
        end
      end

      it "returns empty array" do
        expect(resource_with_non_enum_model.auto_inferred_filters).to eq([])
      end
    end
  end

  describe ".all_filters" do
    it "combines auto-inferred and defined filters" do
      all = TestLicenseResource.all_filters
      filter_names = all.pluck(:name)

      # Should have both auto-inferred status filter and defined filters
      expect(filter_names).to include(:status)
      expect(filter_names).to include(:created_at)
    end

    it "defined filters come after auto-inferred (allowing override)" do
      all = TestLicenseResource.all_filters
      status_filters = all.select { |f| f[:name] == :status }

      # There should be two status filters: one auto-inferred and one defined
      # The defined one should come last
      expect(status_filters.length).to eq(2)
      expect(all.rindex { |f| f[:name] == :status }).to be > all.index { |f| f[:name] == :status }
    end

    context "when resource has no defined filters" do
      let(:resource_with_no_defined_filters) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = License

          def self.name
            "NoDefinedFiltersResource"
          end
        end
      end

      it "includes auto-inferred enum filters" do
        filters = resource_with_no_defined_filters.all_filters
        status_filter = filters.find { |f| f[:name] == :status }
        expect(status_filter[:type]).to eq(:select)
      end

      it "includes auto-inferred column filters" do
        filters = resource_with_no_defined_filters.all_filters
        filter_types = filters.pluck(:type).uniq
        expect(filter_types).to include(:string).or include(:number)
      end
    end

    context "when model has no enums" do
      let(:resource_with_filters_no_enums) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "FiltersNoEnumsResource"
          end

          filter :name, type: :text
        end
      end

      it "includes defined filters" do
        filters = resource_with_filters_no_enums.all_filters
        name_filter = filters.find { |f| f[:name] == :name }
        expect(name_filter).to be_present
      end

      it "does not include :select type filters" do
        filters = resource_with_filters_no_enums.all_filters
        select_filters = filters.select { |f| f[:type] == :select }
        expect(select_filters).to be_empty
      end
    end
  end

  describe "nested associations" do
    let(:nested_resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = User

        def self.name
          "NestedTestResource"
        end

        has_many :licenses, nested: true, allow_destroy: true, fields: %i[license_key status]
      end
    end

    context "when nested: true is set on has_many" do
      it "stores nested flag in defined_associations" do
        config = nested_resource.defined_associations[:licenses]
        expect(config[:nested]).to be(true)
      end

      it "stores allow_destroy in defined_associations" do
        config = nested_resource.defined_associations[:licenses]
        expect(config[:allow_destroy]).to be(true)
      end

      it "stores fields list in defined_associations" do
        config = nested_resource.defined_associations[:licenses]
        expect(config[:fields]).to eq(%i[license_key status])
      end
    end

    describe ".nested_associations" do
      it "returns NestedAssociation objects for nested: true associations" do
        associations = nested_resource.nested_associations
        expect(associations.length).to eq(1)
        expect(associations.first).to be_a(IronAdmin::NestedAssociation)
      end

      it "sets the association name" do
        assoc = nested_resource.nested_associations.first
        expect(assoc.name).to eq(:licenses)
      end

      it "sets the kind" do
        assoc = nested_resource.nested_associations.first
        expect(assoc.kind).to eq(:has_many)
      end

      it "resolves fields from the explicit fields list" do
        assoc = nested_resource.nested_associations.first
        field_names = assoc.fields.map(&:name)
        expect(field_names).to eq(%i[license_key status])
      end

      it "sets allow_destroy" do
        assoc = nested_resource.nested_associations.first
        expect(assoc.allow_destroy).to be(true)
      end

      it "excludes non-nested associations" do
        resource = Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "MixedAssocResource"
          end

          has_many :licenses
        end

        expect(resource.nested_associations).to eq([])
      end
    end

    describe "field auto-inference" do
      let(:auto_fields_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "AutoFieldsNestedResource"
          end

          has_many :licenses, nested: true
        end
      end

      it "excludes id, timestamps, and foreign key" do
        assoc = auto_fields_resource.nested_associations.first
        field_names = assoc.fields.map(&:name)
        expect(field_names).not_to include(:id)
        expect(field_names).not_to include(:created_at)
        expect(field_names).not_to include(:updated_at)
        expect(field_names).not_to include(:user_id)
      end

      it "includes data columns" do
        assoc = auto_fields_resource.nested_associations.first
        field_names = assoc.fields.map(&:name)
        expect(field_names).to include(:license_key)
        expect(field_names).to include(:status)
      end
    end

    describe "validation" do
      it "raises when model lacks accepts_nested_attributes_for" do
        bad_resource = Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "BadNestedResource"
          end

          has_many :licenses, nested: true
        end
        # Remove the validation from User temporarily
        allow(User).to receive(:nested_attributes_options).and_return({})

        expect { bad_resource.nested_associations }.to raise_error(
          ArgumentError,
          /User must declare `accepts_nested_attributes_for :licenses`/
        )
      end
    end

    describe "position_field" do
      let(:positional_resource) do
        Class.new(IronAdmin::Resource) do
          self.model_class_override = User

          def self.name
            "PositionalNestedResource"
          end

          has_many :licenses, nested: true, position_field: :max_devices
        end
      end

      it "stores position_field as symbol" do
        assoc = positional_resource.nested_associations.first
        expect(assoc.position_field).to eq(:max_devices)
      end
    end
  end
end
