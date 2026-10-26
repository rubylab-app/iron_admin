require "rails_helper"

RSpec.describe IronAdmin::Configuration::Theme do
  subject(:theme) { described_class.new }

  describe "button defaults" do
    it "sets btn_primary" do
      expect(theme.btn_primary).to include("bg-indigo-600")
    end

    it "sets btn_secondary" do
      expect(theme.btn_secondary).to include("bg-white")
    end

    it "sets btn_danger" do
      expect(theme.btn_danger).to include("bg-red-600")
    end

    it "sets btn_ghost" do
      expect(theme.btn_ghost).to include("bg-gray-100")
    end
  end

  describe "link defaults" do
    it "sets link" do
      expect(theme.link).to include("text-indigo-600")
    end

    it "sets link_muted" do
      expect(theme.link_muted).to include("text-gray-500")
    end
  end

  describe "input defaults" do
    it "sets focus_ring" do
      expect(theme.focus_ring).to include("focus:ring")
    end

    it "sets input_border" do
      expect(theme.input_border).to include("border-gray-300")
    end

    it "sets input_focus" do
      expect(theme.input_focus).to include("focus:border-indigo-500")
    end

    it "sets checkbox_checked" do
      expect(theme.checkbox_checked).to include("checked:bg-indigo-600")
    end
  end

  describe "scope defaults" do
    it "sets scope_active" do
      expect(theme.scope_active).to include("border-indigo-600")
    end

    it "sets scope_inactive" do
      expect(theme.scope_inactive).to include("border-transparent")
    end
  end

  describe "sidebar defaults" do
    it "sets sidebar_bg" do
      expect(theme.sidebar_bg).to eq("bg-gray-900")
    end

    it "sets sidebar_title" do
      expect(theme.sidebar_title).to eq("text-white")
    end

    it "sets sidebar_link" do
      expect(theme.sidebar_link).to eq("text-gray-300")
    end

    it "sets sidebar_link_hover" do
      expect(theme.sidebar_link_hover).to include("hover:bg-gray-800")
    end

    it "sets sidebar_link_active to the hover colors, so the current page looks like a hovered link" do
      expect(theme.sidebar_link_active).to eq("bg-gray-800 text-white")
    end

    it "sets sidebar_group_label" do
      expect(theme.sidebar_group_label).to eq("text-gray-400")
    end
  end

  describe "navbar defaults" do
    it "sets navbar_bg" do
      expect(theme.navbar_bg).to eq("bg-white")
    end

    it "sets navbar_border" do
      expect(theme.navbar_border).to eq("border-gray-200")
    end

    it "sets navbar_search_bg" do
      expect(theme.navbar_search_bg).to eq("bg-gray-50")
    end

    it "sets navbar_search_focus_bg" do
      expect(theme.navbar_search_focus_bg).to include("focus:bg-white")
    end
  end

  describe "table defaults" do
    it "sets table_header_bg" do
      expect(theme.table_header_bg).to eq("bg-gray-50")
    end

    it "sets table_row_hover" do
      expect(theme.table_row_hover).to include("hover:bg-gray-50")
    end

    it "sets table_border" do
      expect(theme.table_border).to eq("divide-gray-200")
    end
  end

  describe "card defaults" do
    it "sets card_bg" do
      expect(theme.card_bg).to eq("bg-white")
    end

    it "sets card_border" do
      expect(theme.card_border).to eq("border-gray-200")
    end

    it "sets card_shadow" do
      expect(theme.card_shadow).to eq("shadow")
    end
  end

  describe "typography defaults" do
    it "sets font_family to empty string" do
      expect(theme.font_family).to eq("")
    end

    it "sets heading_weight" do
      expect(theme.heading_weight).to eq("font-bold")
    end

    it "sets body_text" do
      expect(theme.body_text).to eq("text-gray-900")
    end

    it "sets muted_text" do
      expect(theme.muted_text).to eq("text-gray-500")
    end

    it "sets label_text" do
      expect(theme.label_text).to eq("text-gray-700")
    end
  end

  describe "layout defaults" do
    it "sets border_radius" do
      expect(theme.border_radius).to eq("rounded-lg")
    end

    it "sets main_bg" do
      expect(theme.main_bg).to eq("bg-gray-50")
    end

    it "sets badge_count" do
      expect(theme.badge_count).to include("bg-indigo-600")
    end
  end

  describe "chart defaults" do
    it "sets chart_colors as array of CSS color values" do
      expect(theme.chart_colors).to be_an(Array)
      expect(theme.chart_colors.length).to eq(6)
      expect(theme.chart_colors.first).to include("rgba")
    end

    it "sets chart_border_color" do
      expect(theme.chart_border_color).to eq("rgb(99, 102, 241)")
    end
  end

  describe "customization" do
    it "allows setting btn_primary" do
      theme.btn_primary = "custom-class"

      expect(theme.btn_primary).to eq("custom-class")
    end

    it "allows setting sidebar_bg" do
      theme.sidebar_bg = "bg-blue-900"

      expect(theme.sidebar_bg).to eq("bg-blue-900")
    end

    it "allows setting border_radius" do
      theme.border_radius = "rounded-xl"

      expect(theme.border_radius).to eq("rounded-xl")
    end
  end
end
