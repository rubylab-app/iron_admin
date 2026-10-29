require "rails_helper"

RSpec.describe IronAdmin::Layout::ShellComponent, type: :component do
  describe "#initialize" do
    it "accepts current_user parameter" do
      user = instance_double(User, name: "Test User")
      component = described_class.new(current_user: user)

      expect(component.instance_variable_get(:@current_user)).to eq(user)
    end

    it "defaults current_user to nil" do
      component = described_class.new

      expect(component.instance_variable_get(:@current_user)).to be_nil
    end
  end

  describe "#before_render" do
    it "is defined" do
      component = described_class.new
      expect(component).to respond_to(:before_render)
    end
  end

  describe "mobile drawer backdrop" do
    subject(:backdrop) do
      with_controller_class(IronAdmin::ApplicationController) do
        render_inline(described_class.new).at_css("[data-cp-sidebar-target='backdrop']")
      end
    end

    it "uses the theme's translucent overlay background" do
      expect(backdrop[:class].split).to include("bg-zinc-900/40")
    end

    it "does not use the bg-opacity utility that Tailwind v4 removed" do
      expect(backdrop[:class]).not_to include("bg-opacity")
    end

    context "with a registered theme active" do
      before do
        IronAdmin::RequestContext.theme = IronAdmin.configuration.register_theme(:midnight) { |t| t.overlay_bg = "bg-black/60" }
      end

      it "uses that theme's overlay background" do
        expect(backdrop[:class].split).to include("bg-black/60")
      end

      it "drops the default theme's overlay background" do
        expect(backdrop[:class].split).not_to include("bg-zinc-900/40")
      end
    end
  end

  describe "skip link" do
    subject(:skip_link) do
      with_controller_class(IronAdmin::ApplicationController) do
        render_inline(described_class.new).at_css("a[href='#main-content']")[:class].split
      end
    end

    it "styles the focused link with the theme's skip_link classes" do
      expect(skip_link).to include("focus:bg-white", "focus:text-zinc-900", "focus:ring-indigo-500")
    end

    it "rounds it like the other controls" do
      expect(skip_link).to include("rounded-md")
    end

    context "with a registered theme active" do
      before do
        IronAdmin::RequestContext.theme = IronAdmin.configuration.register_theme(:midnight) do |t|
          t.skip_link = "focus:bg-zinc-900 focus:text-white"
          t.control_radius = "rounded-none"
        end
      end

      it "uses that theme's skip_link and control_radius classes" do
        expect(skip_link).to include("focus:bg-zinc-900", "focus:text-white", "rounded-none")
      end
    end
  end

  describe "content behind the mobile drawer" do
    # The cp-sidebar controller makes these inert while the drawer is open below lg.
    subject(:content) do
      with_controller_class(IronAdmin::ApplicationController) do
        render_inline(described_class.new) { "Page body" }.css("[data-cp-sidebar-target='content']")
      end
    end

    it "includes the skip link" do
      expect(content.pluck(:href)).to include("#main-content")
    end

    it "includes the column with the navbar and the main landmark" do
      expect(content.count { |element| element.at_css("header") && element.at_css("main#main-content") }).to eq(1)
    end

    it "leaves out the sidebar" do
      expect(content.select { |element| element.at_css("#cp-sidebar-panel") }).to be_empty
    end

    it "leaves out the backdrop, which closes the drawer when clicked" do
      expect(content.select { |element| element.at_css("[data-cp-sidebar-target='backdrop']") }).to be_empty
    end
  end

  describe "slots" do
    it "declares sidebar slot" do
      expect(described_class.registered_slots).to have_key(:sidebar)
    end

    it "declares navbar slot" do
      expect(described_class.registered_slots).to have_key(:navbar)
    end
  end

  describe "component class" do
    it "inherits from ViewComponent::Base" do
      expect(described_class.superclass).to eq(ViewComponent::Base)
    end
  end

  describe "rendering" do
    # The navbar and sidebar templates use IronAdmin's helpers (theme `t`,
    # heroicon), so render through the engine's controller as the app does.
    subject(:rendered) { render_shell(described_class.new) }

    def render_shell(shell)
      with_controller_class(IronAdmin::ApplicationController) { render_inline(shell) { "Page body" } }
    end

    let(:custom_navbar) do
      # The custom navbar from docs/guides/components.md ("Creating Custom Components").
      component = Class.new(ViewComponent::Base) do
        def initialize(title:, current_user:)
          super()
          @title = title
          @current_user = current_user
        end

        def call
          tag.nav("#{@title} custom navbar", id: "custom-navbar")
        end
      end
      stub_const("ShellSpecNavbarComponent", component)
    end

    let(:custom_sidebar) do
      component = Class.new(ViewComponent::Base) do
        def initialize(current_user: nil)
          super()
          @current_user = current_user
        end

        def call
          tag.aside("Custom sidebar", id: "custom-sidebar")
        end
      end
      stub_const("ShellSpecSidebarComponent", component)
    end

    context "without overrides" do
      it "renders the built-in sidebar" do
        expect(rendered.css("#cp-sidebar-panel")).to be_present
      end

      it "renders the built-in navbar" do
        expect(rendered.css("header input[name='q']")).to be_present
      end

      it "renders the page content" do
        expect(rendered.text).to include("Page body")
      end

      it "renders the page content in the main landmark" do
        expect(rendered.at_css("main#main-content").text).to include("Page body")
      end

      it "keeps the content area classes on the main landmark" do
        expect(rendered.at_css("main#main-content")[:class].split).to include("flex-1", "overflow-auto")
      end

      it "renders a skip link to the main landmark first" do
        expect(rendered.at_css("a")[:href]).to eq("#main-content")
      end

      it "hides the skip link until it is focused" do
        expect(rendered.at_css("a[href='#main-content']")[:class].split).to include("sr-only", "focus:not-sr-only")
      end
    end

    context "with a page title" do
      subject(:rendered) do
        with_controller_class(IronAdmin::ApplicationController) do
          render_inline(described_class.new) { "<h1>Users</h1>".html_safe }
        end
      end

      it "renders it as the page's only h1" do
        expect(rendered.css("h1").map { |heading| heading.text.strip }).to eq(["Users"])
      end
    end

    context "with a flash message" do
      subject(:rendered) do
        with_controller_class(IronAdmin::ApplicationController) do
          vc_test_controller.flash[:notice] = "User created."
          render_inline(described_class.new) { "Page body" }
        end
      end

      let(:html) { rendered.to_html }

      it "renders it as an alert" do
        expect(rendered.at_css("[role='alert']").text.squish).to eq("User created.")
      end

      it "renders it above the page content" do
        expect(html.index("User created.")).to be < html.index("Page body")
      end
    end

    context "with a global navbar override" do
      before do
        IronAdmin.configuration.title = "Acme Admin"
        IronAdmin.configuration.components.navbar = custom_navbar
      end

      it "renders the override with the configured title" do
        expect(rendered.css("#custom-navbar").text).to eq("Acme Admin custom navbar")
      end

      it "drops the built-in navbar" do
        expect(rendered.css("header input[name='q']")).to be_empty
      end

      it "keeps the built-in sidebar" do
        expect(rendered.css("#cp-sidebar-panel")).to be_present
      end
    end

    context "with a global sidebar override given as a class name" do
      before do
        custom_sidebar
        IronAdmin.configuration.components.sidebar = "ShellSpecSidebarComponent"
      end

      it "renders the override" do
        expect(rendered.css("#custom-sidebar")).to be_present
      end

      it "drops the built-in sidebar" do
        expect(rendered.css("#cp-sidebar-panel")).to be_empty
      end
    end

    context "with a global flash override" do
      subject(:rendered) do
        with_controller_class(IronAdmin::ApplicationController) do
          vc_test_controller.flash[:notice] = "User created."
          render_inline(described_class.new(current_user: "admin@example.com")) { "Page body" }
        end
      end

      let(:custom_flash) do
        component = Class.new(ViewComponent::Base) do
          def initialize(flash:, current_user:)
            super()
            @flash = flash
            @current_user = current_user
          end

          def call
            tag.div("#{@flash[:notice]} for #{@current_user}", id: "custom-flash")
          end
        end
        stub_const("ShellSpecFlashComponent", component)
      end

      let(:html) { rendered.to_html }

      before { IronAdmin.configuration.components.flash = custom_flash }

      it "renders the override with the request's flash and the current user" do
        expect(rendered.at_css("#custom-flash").text).to eq("User created. for admin@example.com")
      end

      it "drops the built-in flash messages" do
        expect(rendered.css("[role='alert']")).to be_empty
      end

      it "renders the override in the main landmark" do
        expect(rendered.at_css("main#main-content #custom-flash")).to be_present
      end

      it "renders the override before the page content" do
        expect(html.index("custom-flash")).to be < html.index("Page body")
      end
    end

    context "with the sidebar slot set explicitly" do
      it "renders the configured override" do
        IronAdmin.configuration.components.sidebar = custom_sidebar
        shell = described_class.new
        shell.with_sidebar(current_user: nil)

        expect(render_shell(shell).css("#custom-sidebar")).to be_present
      end
    end
  end
end
