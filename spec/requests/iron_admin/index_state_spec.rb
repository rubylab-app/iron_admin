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
    end
  end
end
