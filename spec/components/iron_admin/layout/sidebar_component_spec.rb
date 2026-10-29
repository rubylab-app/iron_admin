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

  describe "brand" do
    subject(:result) { render_inline(described_class.new) }

    before { IronAdmin.configuration.title = "Meridian Admin" }

    it "is not a heading, so the page title stays the page's only h1" do
      expect(result.css("h1, h2, h3, h4, h5, h6")).to be_empty
    end

    it "shows the configured title" do
      expect(result.at_xpath(".//div[normalize-space(text())='Meridian Admin']")).to be_present
    end

    it "sets the title in the theme's heading weight" do
      expect(result.at_xpath(".//div[normalize-space(text())='Meridian Admin']")[:class].split).to include("font-semibold")
    end

    it "puts the brand in a row as high as the navbar" do
      expect(result.at_css("#cp-sidebar-panel > div")[:class].split).to include("h-14")
    end

    context "with a logo" do
      before { IronAdmin.configuration.logo = "/images/logo.png" }

      it "renders the logo instead of the title" do
        expect(result.at_css("img.h-8")&.[](:src)).to eq("/images/logo.png")
      end

      it "renders no heading" do
        expect(result.css("h1, h2, h3, h4, h5, h6")).to be_empty
      end
    end
  end

  describe "current page link" do
    subject(:result) { with_request_url(path) { render_inline(described_class.new) } }

    let(:current_links) { result.css("a[aria-current='page']").pluck(:href) }

    before do
      tool_class = Class.new(IronAdmin::Tool) do
        def self.name = "SidebarActiveTool"
      end
      tool_class.menu label: "Active Tool", group: "Utilities"
      IronAdmin::ToolRegistry.register(tool_class)
      IronAdmin::MenuRegistry.register(IronAdmin::MenuItem.new(label: "Reports", path: "/admin/reports"))
    end

    context "when on the dashboard" do
      let(:path) { "/admin" }

      it "marks only the dashboard link as the current page" do
        expect(current_links).to eq(["/admin/"])
      end
    end

    {
      "index" => "/admin/users",
      "show" => "/admin/users/1",
      "edit" => "/admin/users/1/edit",
      "new" => "/admin/users/new",
      "import" => "/admin/users/import",
      "action form" => "/admin/users/1/actions/deactivate/form",
    }.each do |page, page_path|
      context "when on a resource's #{page} page" do
        let(:path) { page_path }

        it "marks only that resource's link as the current page" do
          expect(current_links).to eq(["/admin/users"])
        end
      end
    end

    {
      "page" => "/admin/tools/sidebar_active",
      "action form" => "/admin/tools/sidebar_active/flush/form",
    }.each do |page, page_path|
      context "when on a tool's #{page}" do
        let(:path) { page_path }

        it "marks only the tool's link as the current page" do
          expect(current_links).to eq(["/admin/tools/sidebar_active"])
        end
      end
    end

    context "when on a custom menu item's path" do
      let(:path) { "/admin/reports" }

      it "marks only the menu item's link as the current page" do
        expect(current_links).to eq(["/admin/reports"])
      end
    end

    context "when on a custom menu item's path with a query string" do
      let(:path) { "/admin/reports?range=week" }

      it "marks the menu item's link as the current page" do
        expect(current_links).to eq(["/admin/reports"])
      end
    end

    context "with a custom menu item that links to an absolute URL" do
      before { IronAdmin::MenuRegistry.register(IronAdmin::MenuItem.new(label: "Stats", path: "http://test.host/admin/stats")) }

      context "when on that URL" do
        let(:path) { "/admin/stats" }

        it "marks the menu item's link as the current page" do
          expect(current_links).to eq(["http://test.host/admin/stats"])
        end
      end

      context "when on the same path on another host" do
        let(:path) { "/admin/stats" }

        before { vc_test_request.host = "other.host" }

        it "marks no link as the current page" do
          expect(current_links).to be_empty
        end
      end
    end

    context "when on a page with no sidebar link" do
      let(:path) { "/admin/search" }

      it "marks no link as the current page" do
        expect(current_links).to be_empty
      end
    end

    context "when the query string names a resource and a tool" do
      let(:path) { "/admin/search?resource_name=users&tool_name=sidebar_active" }

      it "marks no link as the current page" do
        expect(current_links).to be_empty
      end
    end

    describe "link classes" do
      let(:path) { "/admin/users" }
      let(:active_link) { result.at_css("a[aria-current='page']")[:class].split }
      let(:other_link) { result.at_css("a[href='/admin/licenses']")[:class].split }

      before { IronAdmin.configuration.theme.sidebar_link_active = "bg-indigo-700 text-white" }

      it "styles the current page's link with the theme's sidebar_link_active classes" do
        expect(active_link).to include("bg-indigo-700", "text-white")
      end

      it "drops the inactive link classes from the current page's link" do
        expect(active_link).not_to include("text-zinc-600", "hover:bg-zinc-200/60")
      end

      it "keeps the inactive link classes on the other links" do
        expect(other_link).to include("text-zinc-600", "hover:bg-zinc-200/60")
      end

      it "leaves the active classes off the other links" do
        expect(other_link).not_to include("bg-indigo-700")
      end

      it "positions every link, so the active link's before: accent bar stays inside it" do
        expect([active_link, other_link]).to all(include("relative"))
      end
    end
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

  describe "theme" do
    subject(:result) { with_request_url("/admin/users") { render_inline(described_class.new) } }

    let(:panel) { result.at_css("#cp-sidebar-panel")[:class].split }
    let(:group_label) { result.at_css("div.mt-6 > p")[:class].split }
    let(:link) { result.at_css("a[href='/admin/licenses']")[:class].split }
    let(:close_button) { result.at_css("button[aria-label='Close menu']")[:class].split }

    context "with the default theme" do
      it "shares the page background" do
        expect(panel).to include("bg-zinc-50")
      end

      it "separates the sidebar with the theme's sidebar_border on large screens" do
        expect(panel).to include("lg:border-r", "border-zinc-200")
      end

      it "writes the group labels small, in the theme's group label color" do
        expect(group_label).to include("text-xs", "text-zinc-500")
      end

      it "keeps the group labels as written" do
        expect(group_label).not_to include("uppercase")
      end

      it "sets the links in small medium text" do
        expect(link).to include("text-sm", "font-medium")
      end

      it "rounds the links with the theme's control_radius" do
        expect(link).to include("rounded-md")
      end

      it "outlines the focused link with the theme's focus_ring" do
        expect(link).to include("focus-visible:outline-indigo-500")
      end

      it "styles the close button as a ghost icon button" do
        expect(close_button).to include("hover:bg-zinc-100", "rounded-md")
      end
    end

    context "with a registered theme active" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:brutal) do |t|
          t.sidebar_bg = "bg-yellow-300"
          t.sidebar_border = "lg:border-r-2 border-black"
          t.sidebar_group_label = "text-black"
          t.label_transform = "uppercase tracking-widest"
          t.control_radius = "rounded-none"
        end
      end

      it "uses that theme's sidebar background and edge" do
        expect(panel).to include("bg-yellow-300", "lg:border-r-2", "border-black")
      end

      it "drops the default theme's sidebar background and edge" do
        expect(panel).not_to include("bg-zinc-50", "lg:border-r", "border-zinc-200")
      end

      it "writes the group labels with that theme's label_transform and color" do
        expect(group_label).to include("uppercase", "tracking-widest", "text-black")
      end

      it "rounds the links with that theme's control_radius" do
        expect(link).to include("rounded-none")
      end
    end
  end
end
