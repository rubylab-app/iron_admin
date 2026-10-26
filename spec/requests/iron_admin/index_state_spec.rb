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
  end
end
