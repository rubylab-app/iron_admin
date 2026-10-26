# frozen_string_literal: true

require "rails_helper"

# The index page's state (scope, search, filters, sort and page) lives in the
# URL. Every index control must keep the parts it does not change, and the
# records frame must write its navigations to the address bar.
RSpec.describe "Index state", type: :request do
  let(:state_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = License

      def self.name = "IndexStateLicenseResource"
      def self.resource_name = "index_state_licenses"

      searchable :license_key

      filter :status, type: :select
      filter :license_key, type: :string
      filter :max_devices, type: :number
      filter :created_at, type: :date_range

      scope :active, -> { where(status: :active) }, default: true
      scope :expired, -> { where(status: :expired) }

      bulk_action :export do |licenses|
        licenses.pluck(:license_key)
      end

      bulk_action :revoke do |licenses|
        licenses.update_all(status: License.statuses[:revoked])
      end

      index_fields :license_key, :status, :expires_at
    end
  end

  let(:filters) do
    {
      "status" => "expired",
      "license_key" => { "op" => "contains", "value" => "KEY" },
      "max_devices" => { "op" => "between", "value" => "1", "value_2" => "9" },
      "created_at_from" => "2024-01-01",
    }
  end
  let(:state) do
    { "scope" => "expired", "q" => "KEY", "sort" => "expires_at", "direction" => "asc", "page" => "2",
      "filters" => filters, }
  end
  let(:document) { Nokogiri::HTML(response.body) }

  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(state_resource)
  end

  def query_of(url)
    Rack::Utils.parse_nested_query(URI.parse(url).query)
  end

  def sort_link(column)
    document.css("turbo-frame#records thead a").find { |link| link.text.squish == column }
  end

  def hidden_fields(form)
    form.css("input[type=hidden]").reject { |input| input[:name] == "authenticity_token" }
      .to_h { |input| [input[:name], input[:value]] }
  end

  def form_with(selector)
    document.at_css(selector).ancestors("form").first
  end

  describe "GET /:resource_name" do
    # The state above asks for page 2, so two matching licenses on one-row pages make that page real.
    before do
      IronAdmin.configuration.per_page = 1
      create_list(:license, 2, status: :expired)
    end

    context "with a page past the last page" do
      subject(:redirect_query) { query_of(response.location) }

      before { get iron_admin.resources_path("index_state_licenses", state.merge("page" => "9")), as: :html }

      it "redirects to the last page" do
        expect(redirect_query["page"]).to eq("2")
      end

      it "keeps the scope, search, filters and sort" do
        expect(redirect_query.except("page")).to eq(state.except("page"))
      end
    end

    describe "records frame" do
      subject(:frame) { document.at_css("turbo-frame#records") }

      before do
        IronAdmin.configuration.per_page = 1
        create_list(:license, 2)
        get iron_admin.resources_path("index_state_licenses"), as: :html
      end

      it "promotes its navigations to page visits so the URL and history follow them" do
        expect(frame["data-turbo-action"]).to eq("advance")
      end

      it "lets the pagination links navigate the frame" do
        expect(frame.css("nav[aria-label='Pagination'] a:not([data-turbo-frame])")).not_to be_empty
      end

      # The search and filter forms sit outside the frame and must pick up the new sort.
      it "sends the sort links to the whole page" do
        expect(frame.css("thead a").pluck("data-turbo-frame")).to eq(%w[_top _top _top])
      end
    end

    describe "sort links" do
      subject(:sort_query) { query_of(sort_link("Expires at")[:href]) }

      context "with an active scope, search, filters, sort and page" do
        before { get iron_admin.resources_path("index_state_licenses", state), as: :html }

        it "keeps the filters" do
          expect(sort_query["filters"]).to eq(filters)
        end

        it "keeps the scope and the search" do
          expect(sort_query).to include("scope" => "expired", "q" => "KEY")
        end

        it "reverses the direction of the sorted column" do
          expect(sort_query).to include("sort" => "expires_at", "direction" => "desc")
        end

        it "goes back to the first page" do
          expect(sort_query).not_to have_key("page")
        end
      end

      context "with a filter param the resource does not define" do
        before do
          get iron_admin.resources_path("index_state_licenses", filters: { "status" => "expired", "bogus" => "1" }),
              as: :html
        end

        it "keeps only the defined filters" do
          expect(sort_query["filters"]).to eq("status" => "expired")
        end
      end

      context "with the bundled DataTableComponent as the table override" do
        before do
          IronAdmin.configuration.components.table = IronAdmin::Resources::DataTableComponent
          get iron_admin.resources_path("index_state_licenses", state), as: :html
        end

        it "keeps the filters" do
          expect(sort_query["filters"]).to eq(filters)
        end

        it "keeps the scope and the search" do
          expect(sort_query).to include("scope" => "expired", "q" => "KEY")
        end

        it "goes back to the first page" do
          expect(sort_query).not_to have_key("page")
        end
      end
    end

    describe "search form" do
      subject(:search_fields) { hidden_fields(form_with("input[type=text][name=q]")) }

      before { get iron_admin.resources_path("index_state_licenses", state), as: :html }

      it "keeps the sort and direction" do
        expect(search_fields).to include("sort" => "expires_at", "direction" => "asc")
      end

      it "keeps the scope and filters" do
        expect(search_fields).to include(
          "scope" => "expired", "filters[status]" => "expired",
          "filters[license_key][op]" => "contains", "filters[license_key][value]" => "KEY",
          "filters[max_devices][value_2]" => "9", "filters[created_at_from]" => "2024-01-01"
        )
      end

      it "goes back to the first page" do
        expect(search_fields).not_to have_key("page")
      end
    end

    describe "search override" do
      subject(:hidden_params) { probe.received[:hidden_params] }

      let(:probe) do
        Class.new(ViewComponent::Base) do
          class << self
            attr_accessor :received
          end

          def initialize(**options)
            super()
            self.class.received = options
          end

          def call = tag.div(id: "search-probe")
        end
      end

      before do
        stub_const("IndexStateSearchProbe", probe)
        IronAdmin.configuration.components.search = IndexStateSearchProbe
        get iron_admin.resources_path("index_state_licenses", state), as: :html
      end

      it "passes the sort and direction as hidden params" do
        expect(hidden_params).to include("sort" => "expires_at", "direction" => "asc")
      end

      it "leaves the page out of the hidden params" do
        expect(hidden_params).not_to have_key("page")
      end
    end

    describe "filter form" do
      subject(:filter_form) { form_with("select[name='filters[status]']") }

      before { get iron_admin.resources_path("index_state_licenses", state), as: :html }

      it "keeps the sort and direction" do
        expect(hidden_fields(filter_form)).to include("sort" => "expires_at", "direction" => "asc")
      end

      it "keeps the sort and direction when clearing the filters" do
        clear_link = filter_form.css("a").find { |link| link.text.squish == "Clear" }

        expect(query_of(clear_link[:href])).to include("sort" => "expires_at", "direction" => "asc")
      end
    end

    describe "bulk actions form" do
      subject(:bulk_fields) { hidden_fields(document.at_css("form#bulk-actions-form")) }

      context "with an active scope, search, filters, sort and page" do
        before { get iron_admin.resources_path("index_state_licenses", state), as: :html }

        it "carries the index state to the bulk action" do
          expect(bulk_fields).to eq(
            "scope" => "expired", "q" => "KEY", "sort" => "expires_at", "direction" => "asc", "page" => "2",
            "filters[status]" => "expired",
            "filters[license_key][op]" => "contains", "filters[license_key][value]" => "KEY",
            "filters[max_devices][op]" => "between", "filters[max_devices][value]" => "1",
            "filters[max_devices][value_2]" => "9", "filters[created_at_from]" => "2024-01-01"
          )
        end
      end

      context "without index params" do
        before { get iron_admin.resources_path("index_state_licenses"), as: :html }

        it "carries nothing" do
          expect(bulk_fields).to be_empty
        end
      end
    end
  end

  describe "POST /:resource_name/bulk_actions/:action_name" do
    subject(:location) { URI.parse(response.location) }

    let(:licenses) { create_list(:license, 2, status: :expired) }

    context "with the index state it was run from" do
      before do
        # The two licenses match the whole state, so one-row pages make page 2 real.
        IronAdmin.configuration.per_page = 1
        post iron_admin.resource_bulk_action_path("index_state_licenses", "export"),
             params: state.merge("ids" => licenses.map(&:id)), as: :html
      end

      it "redirects to the resource index" do
        expect(location.path).to eq(iron_admin.resources_path("index_state_licenses"))
      end

      it "keeps the scope, search, filters, sort and page" do
        expect(query_of(response.location)).to eq(state)
      end
    end

    context "when no record is selected" do
      before do
        post iron_admin.resource_bulk_action_path("index_state_licenses", "export"), params: state, as: :html
      end

      it "keeps the index state" do
        expect(query_of(response.location)).to eq(state)
      end
    end

    context "when the action empties the page it was run from" do
      let(:licenses) { create_list(:license, 3, status: :expired) }

      before do
        IronAdmin.configuration.per_page = 2
        post iron_admin.resource_bulk_action_path("index_state_licenses", "revoke"),
             params: { "scope" => "expired", "page" => "2", "ids" => [licenses.last.id] }, as: :html
      end

      it "returns to the last page left" do
        expect(query_of(response.location)).to eq("scope" => "expired", "page" => "1")
      end

      it "shows the rows left on that page" do
        follow_redirect!

        expect(document.css("turbo-frame#records input[name='ids[]']").size).to eq(2)
      end
    end

    context "when the list cannot be counted after the action" do
      let(:licenses) { create_list(:license, 3, status: :expired) }

      before do
        allow(IronAdmin.configuration).to receive(:per_page).and_raise(ActiveRecord::ConnectionNotEstablished)
        post iron_admin.resource_bulk_action_path("index_state_licenses", "revoke"),
             params: { "scope" => "expired", "page" => "2", "ids" => [licenses.last.id] }, as: :html
      end

      it "keeps the page" do
        expect(query_of(response.location)).to eq("scope" => "expired", "page" => "2")
      end

      it "still reports the action as done" do
        expect(flash[:notice]).to eq(I18n.t("iron_admin.resources.bulk_action.success"))
      end
    end

    context "with params outside the index state" do
      before do
        post iron_admin.resource_bulk_action_path("index_state_licenses", "export"),
             params: { "ids" => licenses.map(&:id), "host" => "evil.example", "protocol" => "javascript",
                       "only_path" => "false", "sort" => { "nested" => "1" }, "filters" => { "bogus" => "1" }, },
             as: :html
      end

      it "stays on this application" do
        expect(location.host).to eq("www.example.com")
      end

      it "redirects to the resource index" do
        expect(location.path).to eq(iron_admin.resources_path("index_state_licenses"))
      end

      it "drops them" do
        expect(location.query).to be_nil
      end
    end
  end
end
