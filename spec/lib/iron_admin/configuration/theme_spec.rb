require "rails_helper"

RSpec.describe IronAdmin::Configuration::Theme do
  subject(:theme) { described_class.new }

  # The built-in Neutral look.
  neutral = {
    btn_primary: "bg-zinc-900 text-white hover:bg-zinc-700 focus-visible:outline-2 focus-visible:outline-offset-2 " \
                 "focus-visible:outline-indigo-500",
    btn_secondary: "bg-white text-zinc-900 border border-zinc-200 hover:bg-zinc-50 hover:border-zinc-300",
    btn_danger: "bg-red-600 text-white hover:bg-red-700",
    btn_ghost: "bg-transparent text-zinc-700 hover:bg-zinc-100 hover:text-zinc-900",
    link: "text-indigo-600 hover:text-indigo-500",
    link_muted: "text-zinc-500 hover:text-zinc-900",
    focus_ring: "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500",
    input_border: "border-zinc-200 hover:border-zinc-300",
    input_focus: "focus:border-indigo-500 focus:ring-3 focus:ring-indigo-500/15",
    checkbox_checked: "checked:border-indigo-600 checked:bg-indigo-600 focus:ring-3 focus:ring-indigo-500/15",
    input_error: "border-red-400 focus:border-red-500 focus:ring-3 focus:ring-red-500/20",
    placeholder_text: "placeholder:text-zinc-500",
    disabled_text: "text-zinc-300",
    control_radius: "rounded-md",
    scope_active: "border-zinc-900 text-zinc-900",
    scope_inactive: "border-transparent text-zinc-500 hover:text-zinc-900 hover:border-zinc-300",
    badge_count: "bg-zinc-100 text-zinc-700",
    sidebar_bg: "bg-zinc-50",
    sidebar_border: "lg:border-r border-zinc-200",
    sidebar_title: "text-zinc-900",
    sidebar_link: "text-zinc-600",
    sidebar_link_hover: "hover:bg-zinc-200/60 hover:text-zinc-900",
    sidebar_link_active: "bg-white text-zinc-900 shadow-xs ring-1 ring-zinc-200 before:absolute before:left-0 " \
                         "before:inset-y-2 before:w-0.5 before:rounded-full before:bg-indigo-500",
    sidebar_group_label: "text-zinc-500",
    navbar_bg: "bg-white",
    navbar_border: "border-zinc-200",
    navbar_search_bg: "bg-zinc-50",
    navbar_search_focus_bg: "focus:bg-white",
    navbar_text: "text-zinc-600",
    kbd: "border-zinc-200 bg-white text-zinc-500",
    skip_link: "focus:bg-white focus:text-zinc-900 focus:ring-2 focus:ring-indigo-500",
    table_header_bg: "bg-zinc-50",
    table_header_text: "text-xs font-medium text-zinc-500",
    table_cell_padding: "px-4 py-2.5",
    table_frame: "",
    table_row_hover: "hover:bg-zinc-50",
    table_border: "divide-zinc-200",
    card_bg: "bg-white",
    card_border: "border-zinc-200",
    card_shadow: "shadow-xs",
    card_title: "text-sm font-semibold text-zinc-900",
    font_family: "font-[family-name:Inter,ui-sans-serif,system-ui,sans-serif]",
    font_stylesheet_url: "https://fonts.googleapis.com/css2?family=Inter:wght@400..700&display=swap",
    heading_font: "",
    heading_weight: "font-semibold",
    page_title: "text-xl font-semibold tracking-tight text-zinc-900",
    label_transform: "",
    body_text: "text-zinc-900",
    muted_text: "text-zinc-500",
    label_text: "text-zinc-700",
    error_text: "text-red-600",
    success_text: "text-emerald-700",
    main_bg: "bg-zinc-50",
    border_radius: "rounded-lg",
    border_width: "border",
    color_scheme: "light",
    swatch: "bg-white ring-1 ring-inset ring-zinc-300",
    surface_muted: "bg-zinc-50",
    item_hover: "hover:bg-zinc-100",
    icon_muted: "text-zinc-400",
    overlay_bg: "bg-zinc-900/40",
    badge_shape: "rounded-md font-medium",
    chip: "bg-zinc-100 text-zinc-700 ring-1 ring-inset ring-zinc-200",
    danger_item: "text-red-600 hover:bg-red-50 hover:text-red-700",
    tooltip: "bg-zinc-900 text-white",
    code_block: "bg-zinc-950 text-zinc-100",
    progress_track: "bg-zinc-200",
    pagination_active: "bg-zinc-900 text-white border-zinc-900",
    metric_label: "text-xs font-medium text-zinc-500",
    metric_value: "text-2xl font-semibold tracking-tight tabular-nums text-zinc-900",
    metric_icon: "bg-zinc-100 text-zinc-500",
    chart_border_color: "rgb(99, 102, 241)",
    chart_grid_color: "rgba(228, 228, 231, 1)",
    chart_text_color: "rgb(113, 113, 122)",
  }

  describe "Neutral defaults" do
    let(:palette_colors) { %i[green red yellow blue indigo purple pink orange teal gray] }

    neutral.each do |property, value|
      it "sets #{property}" do
        expect(theme.public_send(property)).to eq(value)
      end
    end

    it "sets chart_colors to six translucent CSS colors" do
      expect(theme.chart_colors).to eq(%w[
                                         rgba(99,102,241,0.85) rgba(14,165,233,0.85) rgba(16,185,129,0.85)
                                         rgba(245,158,11,0.85) rgba(244,63,94,0.85) rgba(139,92,246,0.85)
                                       ])
    end

    it "sets alert_palette for every alert type" do
      expect(theme.alert_palette.keys).to eq(%i[success error warning info])
    end

    it "tints the success alert" do
      expect(theme.alert_palette[:success]).to eq("bg-emerald-50 border-emerald-200 text-emerald-800")
    end

    it "sets badge_palette for every badge color" do
      expect(theme.badge_palette.keys).to eq(palette_colors)
    end

    it "tints the green badge with an inset ring" do
      expect(theme.badge_palette[:green]).to eq("bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-600/20")
    end

    it "sets badge_dot_palette for every badge color" do
      expect(theme.badge_dot_palette.keys).to eq(palette_colors)
    end

    it "sets the green badge dot" do
      expect(theme.badge_dot_palette[:green]).to eq("bg-emerald-500")
    end
  end

  describe "Neutral defaults of the form control additions" do
    {
      control_shadow: "shadow-xs",
      checkbox_border: "border-zinc-300",
      checkbox_radius: "rounded-sm",
      item_active: "bg-zinc-100",
      popover_shadow: "shadow-lg",
    }.each do |property, value|
      it "sets #{property}" do
        expect(theme.public_send(property)).to eq(value)
      end
    end
  end

  describe "#name" do
    it "defaults to :neutral" do
      expect(theme.name).to eq(:neutral)
    end

    context "with a String name" do
      subject(:theme) { described_class.new(name: "midnight") }

      it "returns it as a Symbol" do
        expect(theme.name).to eq(:midnight)
      end
    end
  end

  describe "#label" do
    it "defaults to Neutral" do
      expect(theme.label).to eq("Neutral")
    end

    context "with a name and no label" do
      subject(:theme) { described_class.new(name: :dark_blue) }

      it "titleizes the name" do
        expect(theme.label).to eq("Dark Blue")
      end
    end

    context "with a label" do
      subject(:theme) { described_class.new(name: :midnight, label: "Late night") }

      it "returns it" do
        expect(theme.label).to eq("Late night")
      end
    end
  end

  describe "#dark?" do
    it "is false for the light scheme" do
      expect(theme).not_to be_dark
    end

    context "with the dark scheme" do
      before { theme.color_scheme = "dark" }

      it "is true" do
        expect(theme).to be_dark
      end
    end
  end

  describe "#scheme_class" do
    it "returns scheme-light for the light scheme" do
      expect(theme.scheme_class).to eq("scheme-light")
    end

    context "with the dark scheme" do
      before { theme.color_scheme = :dark }

      it "returns scheme-dark" do
        expect(theme.scheme_class).to eq("scheme-dark")
      end
    end

    context "with an unknown scheme" do
      before { theme.color_scheme = "sepia" }

      it "falls back to scheme-light" do
        expect(theme.scheme_class).to eq("scheme-light")
      end
    end
  end

  describe "palettes of separate themes" do
    let(:other) { described_class.new }

    before { theme.badge_palette[:green] = "bg-lime-100" }

    it "are separate Hashes" do
      expect(other.badge_palette[:green]).to start_with("bg-emerald-50")
    end
  end

  describe "#dup" do
    subject(:copy) { theme.dup }

    it "copies chart_colors" do
      copy.chart_colors << "#000000"

      expect(theme.chart_colors.size).to eq(6)
    end

    it "copies alert_palette" do
      copy.alert_palette[:info] = "bg-sky-50"

      expect(theme.alert_palette[:info]).to eq("bg-blue-50 border-blue-200 text-blue-800")
    end

    it "copies badge_palette" do
      copy.badge_palette.delete(:gray)

      expect(theme.badge_palette).to have_key(:gray)
    end

    it "copies badge_dot_palette" do
      copy.badge_dot_palette.clear

      expect(theme.badge_dot_palette).not_to be_empty
    end

    it "keeps the values" do
      expect(copy.badge_palette).to eq(theme.badge_palette)
    end

    it "keeps the name" do
      expect(copy.name).to eq(:neutral)
    end

    context "with a frozen palette" do
      before { theme.badge_palette = theme.badge_palette.freeze }

      it "returns a palette that can be changed" do
        expect { copy.badge_palette[:green] = "bg-lime-100" }.not_to raise_error
      end
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

    it "allows setting font_stylesheet_url to nil" do
      theme.font_stylesheet_url = nil

      expect(theme.font_stylesheet_url).to be_nil
    end
  end
end
