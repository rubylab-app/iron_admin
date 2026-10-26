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

    it "uses a translucent background that Tailwind v4 still generates" do
      expect(backdrop[:class].split).to include("bg-gray-900/50")
    end

    it "does not use the bg-opacity utility that Tailwind v4 removed" do
      expect(backdrop[:class]).not_to include("bg-opacity")
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
