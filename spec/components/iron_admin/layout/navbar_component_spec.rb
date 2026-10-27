require "rails_helper"

RSpec.describe IronAdmin::Layout::NavbarComponent, type: :component do
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

  describe "global search box" do
    subject(:search_input) do
      with_controller_class(controller_class) do
        with_request_url("/admin/#{path}?q=Rails") { render_inline(described_class.new) }
      end.at_css("header input[name='q']")
    end

    context "when on the search results page" do
      let(:controller_class) { IronAdmin::SearchController }
      let(:path) { "search" }

      it "keeps the submitted query" do
        expect(search_input[:value]).to eq("Rails")
      end

      it "has an accessible name" do
        expect(search_input["aria-label"]).to eq("Search across all resources")
      end
    end

    # On an index page, q is that resource's own search box.
    context "when on another page" do
      let(:controller_class) { IronAdmin::ResourcesController }
      let(:path) { "users" }

      it "stays empty" do
        expect(search_input[:value]).to be_blank
      end

      it "has an accessible name" do
        expect(search_input["aria-label"]).to eq("Search across all resources")
      end
    end
  end

  describe "theme switcher" do
    subject(:switcher) { rendered.at_css("header details[data-controller='cp-disclosure']") }

    let(:rendered) do
      with_controller_class(IronAdmin::ResourcesController) do
        with_request_url("/admin/users") { render_inline(described_class.new) }
      end
    end

    context "with only the default theme" do
      it "is hidden" do
        expect(switcher).to be_nil
      end
    end

    context "with two themes" do
      before { IronAdmin.configuration.register_theme(:midnight) }

      it "is shown" do
        expect(switcher).to be_present
      end
    end

    context "with the theme_switcher slot overridden" do
      subject(:override) { rendered.at_css("header .custom-switcher") }

      let(:custom_switcher) do
        component = Class.new(ViewComponent::Base) do
          def initialize(themes:, current_theme:)
            super()
            @names = themes.map(&:name)
            @current = current_theme.name
          end

          def call
            tag.span("#{@names.join(",")}:#{@current}", class: "custom-switcher")
          end
        end
        stub_const("CustomSwitcherComponent", component)
      end

      before do
        IronAdmin.configuration.register_theme(:midnight)
        IronAdmin.configuration.components.theme_switcher = custom_switcher
      end

      it "renders the override with the themes and the current theme" do
        expect(override.text).to eq("neutral,midnight:neutral")
      end
    end
  end

  describe "theme" do
    subject(:rendered) do
      with_controller_class(IronAdmin::ResourcesController) do
        with_request_url("/admin/users") { render_inline(described_class.new(current_user: user)) }
      end
    end

    let(:user) { instance_double(User, name: "Ada Lovelace") }
    let(:header) { rendered.at_css("header")[:class].split }
    let(:search_input) { rendered.at_css("header input[name='q']")[:class].split }
    let(:search_icon) { rendered.at_css("header form svg")[:class].split }
    let(:menu_button) { rendered.at_css("button[aria-label='Open menu']")[:class].split }
    let(:user_name) { rendered.css("header span").find { |span| span.text.strip == "Ada Lovelace" }[:class].split }

    context "with the default theme" do
      it "is a 56px bar with the theme's background and bottom border" do
        expect(header).to include("h-14", "bg-white", "border-b", "border-zinc-200")
      end

      it "makes the search input 36px high" do
        expect(search_input).to include("h-9")
      end

      it "styles the search input with the theme's border, radius and backgrounds" do
        expect(search_input).to include("border", "border-zinc-200", "rounded-md", "bg-zinc-50", "focus:bg-white")
      end

      it "colors the search placeholder and focus ring from the theme" do
        expect(search_input).to include("placeholder:text-zinc-500", "focus:ring-indigo-500/15")
      end

      it "casts the theme's control shadow, like every input" do
        expect(search_input).to include("shadow-xs")
      end

      it "hides the search outline only where the focus ring shows, keeping it in forced-colors mode" do
        expect(search_input).to include("outline-hidden")
      end

      it "mutes the search icon" do
        expect(search_icon).to include("text-zinc-400")
      end

      it "styles the menu button as a ghost icon button" do
        expect(menu_button).to include("hover:bg-zinc-100", "rounded-md", "focus-visible:outline-indigo-500")
      end

      it "writes the user name in the theme's navbar_text color" do
        expect(user_name).to include("text-zinc-600")
      end
    end

    context "with a registered theme active" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:midnight) do |t|
          t.navbar_bg = "bg-zinc-900"
          t.navbar_border = "border-zinc-800"
          t.navbar_search_bg = "bg-zinc-800"
          t.navbar_text = "text-zinc-300"
          t.control_radius = "rounded-full"
        end
      end

      it "uses that theme's navbar background and border" do
        expect(header).to include("bg-zinc-900", "border-zinc-800")
      end

      it "drops the default theme's navbar background" do
        expect(header).not_to include("bg-white")
      end

      it "styles the search input with that theme" do
        expect(search_input).to include("bg-zinc-800", "rounded-full")
      end

      it "writes the user name in that theme's navbar_text color" do
        expect(user_name).to include("text-zinc-300")
      end
    end
  end

  describe "search shortcut" do
    subject(:form) do
      with_controller_class(IronAdmin::ResourcesController) do
        with_request_url("/admin/users") { render_inline(described_class.new) }
      end.at_css("header form[role='search']")
    end

    let(:hint) { form.at_css("kbd") }

    it "attaches the cp-search-shortcut controller to the search form" do
      expect(form["data-controller"]).to eq("cp-search-shortcut")
    end

    it "listens for the shortcut anywhere on the page" do
      expect(form["data-action"]).to eq("keydown@window->cp-search-shortcut#focus")
    end

    it "focuses the search input" do
      expect(form.at_css("input[name='q']")["data-cp-search-shortcut-target"]).to eq("input")
    end

    it "shows the shortcut in a keyboard hint" do
      expect(hint["data-cp-search-shortcut-target"]).to eq("hint")
    end

    it "reads ⌘K until the controller names the platform's shortcut" do
      expect(hint.text.strip).to eq("⌘K")
    end

    it "hides the hint until the controller connects, as the shortcut needs it" do
      expect(hint.key?("hidden")).to be(true)
    end

    it "hides the hint from screen readers" do
      expect(hint["aria-hidden"]).to eq("true")
    end

    it "hides the hint below the sm breakpoint" do
      expect(hint[:class].split).to include("hidden", "sm:inline-flex")
    end

    it "styles the hint with the theme's kbd classes" do
      expect(hint[:class].split).to include("border-zinc-200", "bg-white", "text-zinc-500")
    end

    it "leaves room for the hint in the search input" do
      expect(form.at_css("input[name='q']")[:class].split).to include("sm:pr-16")
    end

    context "with a registered theme active" do
      before do
        IronAdmin::Current.theme = IronAdmin.configuration.register_theme(:midnight) do |t|
          t.kbd = "border-zinc-700 bg-zinc-800 text-zinc-300"
        end
      end

      it "styles the hint with that theme's kbd classes" do
        expect(hint[:class].split).to include("border-zinc-700", "bg-zinc-800", "text-zinc-300")
      end
    end

    describe "controller" do
      it "is registered under the identifier the template uses" do
        entry_point = IronAdmin::Engine.root.join("app/javascript/iron_admin/index.js").read

        expect(entry_point).to include(%(application.register("cp-search-shortcut", CpSearchShortcutController)))
      end

      it "is pinned in the engine's import map" do
        importmap = IronAdmin::Engine.root.join("config/importmap.rb").read

        expect(importmap).to include(%(pin "iron_admin/controllers/cp_search_shortcut_controller"))
      end
    end
  end

  describe "component class" do
    it "inherits from ViewComponent::Base" do
      expect(described_class.superclass).to eq(ViewComponent::Base)
    end
  end
end
