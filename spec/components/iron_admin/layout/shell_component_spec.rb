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
end
