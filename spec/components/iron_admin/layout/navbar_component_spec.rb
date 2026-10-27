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

  describe "component class" do
    it "inherits from ViewComponent::Base" do
      expect(described_class.superclass).to eq(ViewComponent::Base)
    end
  end
end
