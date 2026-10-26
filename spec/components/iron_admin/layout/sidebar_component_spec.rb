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

  describe "drawer close button" do
    subject(:close_button) { render_inline(described_class.new).at_css("button[aria-label='Close menu']") }

    it "closes the drawer" do
      expect(close_button["data-action"]).to eq("cp-sidebar#close")
    end

    it "is the cp-sidebar target that takes focus when the drawer opens" do
      expect(close_button["data-cp-sidebar-target"]).to eq("closeButton")
    end
  end

  context "with custom menu items" do
    subject(:result) { render_inline(described_class.new) }

    before do
      IronAdmin::MenuRegistry.register(
        IronAdmin::MenuItem.new(label: "Reports", path: "/plugins/reports", icon: "chart-bar", group: "Analytics", priority: 20)
      )
      IronAdmin::MenuRegistry.register(
        IronAdmin::MenuItem.new(label: "Billing", path: "/plugins/billing", group: "Analytics", priority: 10)
      )
    end

    it "links to the item's path" do
      expect(result.at_css("a[href='/plugins/reports']")&.text&.strip).to eq("Reports")
    end

    it "renders the item's group heading" do
      expect(result.css("p").map { |heading| heading.text.strip }).to include("Analytics")
    end

    it "orders the items in a group by priority" do
      expect(result.css("a[href^='/plugins/']").map { |a| a.text.strip }).to eq(%w[Billing Reports])
    end

    it "renders the item's icon" do
      expect(result.css("a[href='/plugins/reports'] svg.heroicon-chart-bar")).not_to be_empty
    end

    it "renders no icon for an item without one" do
      expect(result.css("a[href='/plugins/billing'] svg")).to be_empty
    end

    context "when items share a priority" do
      before do
        IronAdmin::MenuRegistry.reset!
        %w[Zeta Alpha Mid].each do |label|
          IronAdmin::MenuRegistry.register(IronAdmin::MenuItem.new(label: label, path: "/plugins/#{label.downcase}"))
        end
      end

      it "keeps their registration order" do
        expect(result.css("a[href^='/plugins/']").map { |a| a.text.strip }).to eq(%w[Zeta Alpha Mid])
      end
    end
  end

  context "with a plugin that adds a menu item" do
    before do
      plugin = Class.new(IronAdmin::Plugin) do
        plugin_name "sidebar_reports"
        setup { |admin| admin.menu_item(label: "Plugin Reports", path: "/plugins/plugin-reports") }
      end
      IronAdmin.register_plugin(plugin)
    end

    it "renders the plugin's link under the default Plugins group" do
      result = render_inline(described_class.new)
      section = result.css("div.mt-6").find { |div| div.at_css("p").text.strip == "Plugins" }

      expect(section.css("a").map { |a| [a.text.strip, a[:href]] }).to eq([["Plugin Reports", "/plugins/plugin-reports"]])
    end
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
