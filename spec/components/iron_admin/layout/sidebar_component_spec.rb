require "rails_helper"

RSpec.describe IronAdmin::Layout::SidebarComponent, type: :component do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)

    vc_test_controller.view_context.class.define_method(:heroicon) do |name, **_opts|
      "<svg class=\"heroicon-#{name}\"></svg>".html_safe
    end
  end

  it "renders resource links" do
    result = render_inline(described_class.new)
    link_texts = result.css("a").map { |a| a.text.strip }

    expect(link_texts).to include("Users")
    expect(link_texts).to include("Licenses")
  end

  it "renders dashboard link" do
    result = render_inline(described_class.new)
    link_texts = result.css("a").map { |a| a.text.strip }

    expect(link_texts).to include("Dashboard")
  end

  it "hides resources the user cannot read" do
    hidden = Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name = "HiddenSidebarResource"
      def self.resource_name = "hidden_sidebar_users"

      deny_actions :read
      menu group: "Secret"
    end
    IronAdmin::ResourceRegistry.register(hidden)

    result = render_inline(described_class.new(current_user: nil))
    hrefs = result.css("a").pluck("href")

    expect(hrefs).not_to include(a_string_including("hidden_sidebar_users"))
  end

  it "groups resources by menu group" do
    result = render_inline(described_class.new)

    expect(result.text).to include("Licensing")
  end

  context "with registered tools" do
    before do
      tool_class = Class.new(IronAdmin::Tool) do
        def self.name = "SidebarTestTool"
      end
      tool_class.menu icon: "wrench", label: "My Tool", priority: 1, group: "Utilities"
      IronAdmin::ToolRegistry.register(tool_class)
    end

    it "renders tool links" do
      result = render_inline(described_class.new)
      link_texts = result.css("a").map { |a| a.text.strip }

      expect(link_texts).to include("My Tool")
    end

    it "groups tools by menu group" do
      result = render_inline(described_class.new)

      expect(result.text).to include("Utilities")
    end
  end
end
