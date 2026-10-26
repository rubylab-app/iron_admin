# frozen_string_literal: true

require "rails_helper"

# Global (config.components), per-resource (Resource.component) and plugin
# component overrides must change what IronAdmin renders, and leave the
# built-in markup alone when no override is set.
RSpec.describe "Component overrides", type: :request do
  let(:user_resource) { IronAdmin::Resources::UserResource }

  around do |example|
    license_overrides = IronAdmin::Resources::LicenseResource.component_overrides
    original_overrides = user_resource.component_overrides
    original_field_overrides = user_resource.field_overrides.dup
    original_form_field_names = user_resource.form_field_names&.dup
    original_filters = user_resource.defined_filters
    example.run
  ensure
    IronAdmin::Resources::LicenseResource.component_overrides = license_overrides
    user_resource.component_overrides = original_overrides
    user_resource.field_overrides = original_field_overrides
    user_resource.form_field_names = original_form_field_names
    user_resource.defined_filters = original_filters
  end

  # ViewComponent only renders named classes.
  def named_component(name, component_class)
    stub_const("ComponentOverridesSpec::#{name}", component_class)
  end

  # Renders the keyword arguments it receives as JSON, so the specs can check
  # exactly what IronAdmin passed to the slot.
  def probe_component(dom_id, *keywords)
    serialize = lambda do |value|
      if value.is_a?(Class) then value.name
      elsif value.is_a?(Enumerable) && !value.is_a?(Hash) then value.map { |item| item.try(:name) || item }
      else value
      end
    end

    probe = Class.new(ViewComponent::Base) do
      define_method(:initialize) do |**options|
        @options = options.slice(*keywords)
      end

      define_method(:call) do
        tag.div(@options.transform_values(&serialize).to_json, id: dom_id)
      end
    end
    named_component(dom_id.underscore.camelize, probe)
  end

  def probe_payload(dom_id)
    JSON.parse(Nokogiri::HTML(response.body).at_css("##{dom_id}").text)
  end

  describe "GET /:resource_name" do
    before do
      User.create!(name: "Ada", email: "ada@example.com", role: "admin")
      User.create!(name: "Grace", email: "grace@example.com", role: "user")
    end

    context "without overrides" do
      before { get iron_admin.resources_path("users") }

      it "renders the built-in table" do
        expect(response.body).to include("<table")
      end

      it "renders the built-in search form" do
        expect(Nokogiri::HTML(response.body).at_css("input[type=text][name=q]")).to be_present
      end

      it "renders the built-in filter dropdown" do
        expect(response.body).to include("<details")
      end
    end

    context "with a global table override" do
      before do
        IronAdmin.configuration.components.table = probe_component("custom-table", :records, :fields, :resource_class)
        get iron_admin.resources_path("users")
      end

      it "renders the override with the page's records" do
        expect(probe_payload("custom-table")["records"]).to contain_exactly("Ada", "Grace")
      end

      it "passes the index fields" do
        expect(probe_payload("custom-table")["fields"]).to include("name", "email")
      end

      it "replaces the built-in table" do
        expect(response.body).not_to include("<table")
      end

      it "keeps the records frame around the override" do
        expect(Nokogiri::HTML(response.body).at_css("turbo-frame#records #custom-table")).to be_present
      end
    end

    context "with a per-resource table override" do
      before do
        IronAdmin.configuration.components.table = probe_component("global-table")
        user_resource.component :table, probe_component("users-table")
        get iron_admin.resources_path("users")
      end

      it "renders the resource's override" do
        expect(response.body).to include('id="users-table"')
      end

      it "takes precedence over the global override" do
        expect(response.body).not_to include('id="global-table"')
      end
    end

    context "with a per-resource table override on another resource" do
      it "keeps the built-in table" do
        IronAdmin::Resources::LicenseResource.component :table, probe_component("licenses-table")
        get iron_admin.resources_path("users")

        expect(response.body).to include("<table")
      end
    end

    context "with the bundled DataTableComponent as the table override" do
      it "renders sort links that keep the current search" do
        IronAdmin.configuration.components.table = IronAdmin::Resources::DataTableComponent
        get iron_admin.resources_path("users", q: "Ada")

        expect(response.body).to include("/admin/users?q=Ada&amp;sort=name&amp;direction=asc")
      end
    end

    context "with a search override" do
      before do
        IronAdmin.configuration.components.search =
          probe_component("custom-search", :form_url, :value, :placeholder, :hidden_params, :resource_class)
        get iron_admin.resources_path("users", q: "Ada", filters: { role: "admin" })
      end

      it "passes the current query" do
        expect(probe_payload("custom-search")).to include("value" => "Ada", "form_url" => "/admin/users")
      end

      it "passes the active filters as hidden params" do
        expect(probe_payload("custom-search")["hidden_params"]).to include("filters[role]" => "admin")
      end

      it "replaces the built-in search form" do
        expect(Nokogiri::HTML(response.body).at_css("input[type=text][name=q]")).to be_nil
      end
    end

    context "with a search override and an active number filter" do
      before do
        user_resource.filter :id, type: :number
        IronAdmin.configuration.components.search = probe_component("custom-search", :hidden_params)
        get iron_admin.resources_path("users", filters: { id: { op: "between", value: "1", "value_2" => "9" } })
      end

      it "passes the operator and both values as hidden params" do
        expect(probe_payload("custom-search")["hidden_params"]).to include(
          "filters[id][op]" => "between", "filters[id][value]" => "1", "filters[id][value_2]" => "9"
        )
      end
    end

    context "with a filter bar override" do
      before do
        IronAdmin.configuration.components.filter_bar =
          probe_component("custom-filter-bar", :filters, :form_url, :query, :active_count)
        get iron_admin.resources_path("users", filters: { role: "admin" })
      end

      it "passes the resource's filters and how many are active" do
        expect(probe_payload("custom-filter-bar")).to include("active_count" => 1, "form_url" => "/admin/users")
      end

      it "replaces the built-in filter dropdown" do
        expect(response.body).not_to include("<details")
      end
    end

    context "with a filter bar override on a resource without filters" do
      it "renders nothing in its place" do
        allow(user_resource).to receive(:all_filters).and_return([])
        IronAdmin.configuration.components.filter_bar = probe_component("custom-filter-bar")
        get iron_admin.resources_path("users")

        expect(response.body).not_to include('id="custom-filter-bar"')
      end
    end
  end

  # LicenseResource declares `filter :created_at, type: :date_range`, which
  # submits as filters[created_at_from] and filters[created_at_to].
  describe "GET /:resource_name with an active date range filter" do
    let(:date_range) { { created_at_from: "2024-01-01", created_at_to: "2024-12-31" } }

    context "without a search override" do
      before { get iron_admin.resources_path("licenses", q: "KEY", filters: date_range) }

      it "keeps both ends of the range as hidden fields in the search form" do
        search_form = Nokogiri::HTML(response.body).at_css("input[type=text][name=q]").ancestors("form").first
        hidden = search_form.css("input[type=hidden]").to_h { |input| [input[:name], input[:value]] }

        expect(hidden).to include("filters[created_at_from]" => "2024-01-01", "filters[created_at_to]" => "2024-12-31")
      end
    end

    context "with a search override" do
      before do
        IronAdmin.configuration.components.search = probe_component("custom-search", :hidden_params)
        get iron_admin.resources_path("licenses", q: "KEY", filters: date_range)
      end

      it "passes both ends of the range as hidden params" do
        expect(probe_payload("custom-search")["hidden_params"]).to include(
          "filters[created_at_from]" => "2024-01-01", "filters[created_at_to]" => "2024-12-31"
        )
      end
    end

    context "with a search override and only the start of the range" do
      let(:date_range) { { created_at_from: "2024-01-01" } }

      before do
        IronAdmin.configuration.components.search = probe_component("custom-search", :hidden_params)
        get iron_admin.resources_path("licenses", q: "KEY", filters: date_range)
      end

      it "leaves out the empty end of the range" do
        expect(probe_payload("custom-search")["hidden_params"]).not_to have_key("filters[created_at_to]")
      end
    end
  end

  describe "GET /:resource_name/new" do
    context "with a global form override" do
      before do
        IronAdmin.configuration.components.form = probe_component("custom-form", :url, :fields, :record)
        get iron_admin.new_resource_path("users")
      end

      it "renders the override with the create URL" do
        expect(probe_payload("custom-form")["url"]).to eq("/admin/users")
      end

      it "replaces the built-in form" do
        expect(response.body).not_to include('name="record[name]"')
      end
    end
  end

  describe "GET /:resource_name/:id/edit" do
    let(:user) { User.create!(name: "Ada", email: "ada@example.com") }

    context "with a per-resource form override" do
      it "renders the override with the update URL" do
        user_resource.component :form, probe_component("users-form", :url)
        get iron_admin.edit_resource_path("users", user)

        expect(probe_payload("users-form")["url"]).to eq("/admin/users/#{user.id}")
      end
    end

    context "with a field component for a custom field type" do
      let(:color_picker) do
        component = Class.new(ViewComponent::Base) do
          def initialize(form:, field:, record:)
            super()
            @form = form
            @field = field
            @record = record
          end

          def call
            @form.text_field(@field.name, class: "color-picker", value: @record.public_send(@field.name))
          end
        end
        named_component("ColorPicker", component)
      end

      before do
        IronAdmin.configuration.components.fields[:color_picker] = color_picker
        user_resource.field :name, type: :color_picker
        user_resource.form_fields :name
        get iron_admin.edit_resource_path("users", user)
      end

      it "renders the component as the field's input" do
        expect(response.body).to include('class="color-picker"')
      end

      it "keeps the field label" do
        expect(response.body).to include('for="record_name"')
      end
    end

    context "with a field component for a built-in field type" do
      before do
        IronAdmin.configuration.components.fields[:email] = probe_component("custom-email-input")
        user_resource.form_fields :email
        get iron_admin.edit_resource_path("users", user)
      end

      it "renders the component" do
        expect(response.body).to include('id="custom-email-input"')
      end

      it "replaces the built-in input" do
        expect(response.body).not_to include('type="email"')
      end
    end
  end

  describe "layout slots" do
    # The dummy app overrides the engine layout, which is where the shell
    # renders, so put the engine's own views first (see layout_spec.rb).
    around do |example|
      original_view_paths = IronAdmin::ApplicationController.view_paths
      IronAdmin::ApplicationController.prepend_view_path(IronAdmin::Engine.root.join("app/views"))
      example.run
    ensure
      IronAdmin::ApplicationController.view_paths = original_view_paths
    end

    let(:custom_shell) do
      component = Class.new(ViewComponent::Base) do
        def initialize(current_user: nil)
          super()
          @current_user = current_user
        end

        def call
          tag.main(content, id: "custom-shell")
        end
      end
      named_component("Shell", component)
    end

    let(:custom_navbar) do
      component = Class.new(ViewComponent::Base) do
        def initialize(title:, current_user:)
          super()
          @title = title
          @current_user = current_user
        end

        def call
          tag.nav("#{@title} navbar", id: "custom-navbar")
        end
      end
      named_component("Navbar", component)
    end

    context "with a shell override" do
      before do
        IronAdmin.configuration.components.shell = custom_shell
        get iron_admin.resources_path("users")
      end

      it "wraps the page in the override" do
        expect(Nokogiri::HTML(response.body).at_css("#custom-shell turbo-frame#records")).to be_present
      end

      it "replaces the built-in shell" do
        expect(response.body).not_to include("cp-sidebar-panel")
      end
    end

    context "with a navbar override" do
      it "renders the override with the configured title" do
        IronAdmin.configuration.title = "Acme Admin"
        IronAdmin.configuration.components.navbar = custom_navbar
        get iron_admin.resources_path("users")

        expect(response.body).to include("Acme Admin navbar")
      end
    end

    context "with a navbar override from a plugin" do
      it "renders the plugin's navbar" do
        navbar = custom_navbar
        plugin = Class.new(IronAdmin::Plugin) do
          plugin_name "component_overrides_spec"
          setup { |admin| admin.component :navbar, navbar }
        end
        IronAdmin.register_plugin(plugin)
        get iron_admin.resources_path("users")

        expect(response.body).to include('id="custom-navbar"')
      end
    end
  end
end
