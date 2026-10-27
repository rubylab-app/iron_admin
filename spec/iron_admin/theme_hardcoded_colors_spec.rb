# frozen_string_literal: true

require "rails_helper"

# Finds colors written in templates, which no theme can change. Colors belong in
# IronAdmin::Configuration::Theme properties.
module ThemeHardcodedColors
  # Files still being migrated to theme properties; each package removes its own.
  PENDING = [
    # chrome package
    "app/components/iron_admin/ui/alert_component.rb",
    "app/components/iron_admin/ui/dropdown_component.rb",
    "app/components/iron_admin/ui/empty_state_component.html.haml",
    "app/components/iron_admin/ui/modal_component.html.haml",
    "app/components/iron_admin/ui/pagination_component.rb",
    "app/components/iron_admin/ui/tooltip_component.rb",
    "app/views/iron_admin/shared/_pagination.html.haml",

    # data package
    "app/components/iron_admin/filters/bar_component.html.haml",
    "app/components/iron_admin/filters/bar_component.rb",
    "app/components/iron_admin/filters/select_filter_component.rb",
    "app/components/iron_admin/resources/data_table_component.html.haml",
    "app/components/iron_admin/ui/badge_component.rb",
    "app/helpers/iron_admin/field_display_helper.rb",
    "app/views/iron_admin/audit/index.html.haml",
    "app/views/iron_admin/resources/index.html.haml",
    "app/views/iron_admin/resources/show.html.haml",
    "app/views/iron_admin/search/index.html.haml",

    # forms package
    "app/components/iron_admin/form/belongs_to_autocomplete_component.html.haml",
    "app/components/iron_admin/form/belongs_to_autocomplete_component.rb",
    "app/components/iron_admin/form/belongs_to_component.html.haml",
    "app/components/iron_admin/form/belongs_to_component.rb",
    "app/components/iron_admin/form/checkbox_component.rb",
    "app/components/iron_admin/form/date_picker_component.rb",
    "app/components/iron_admin/form/field_wrapper_component.html.haml",
    "app/components/iron_admin/form/nested_form_component.html.haml",
    "app/components/iron_admin/form/select_component.rb",
    "app/components/iron_admin/form/text_input_component.rb",
    "app/components/iron_admin/form/textarea_component.rb",
    "app/helpers/iron_admin/theme_helper.rb",
    "app/views/iron_admin/form/_nested_row.html.haml",
    "app/views/iron_admin/imports/new.html.haml",
    "app/views/iron_admin/imports/preview.html.haml",
    "app/views/iron_admin/resources/_form.html.haml",
    "app/views/iron_admin/resources/action_form.html.haml",
    "app/views/iron_admin/resources/bulk_action_form.html.haml",
    "app/views/iron_admin/tools/action_form.html.haml",

    # dashboard package
    "app/components/iron_admin/dashboards/activity_feed_component.rb",
    "app/components/iron_admin/dashboards/activity_feed_component/item_component.html.haml",
    "app/components/iron_admin/dashboards/metric_card_component.html.haml",
    "app/components/iron_admin/dashboards/progress_component.html.haml",
    "app/components/iron_admin/dashboards/quick_links_component/link_component.html.haml",
    "app/components/iron_admin/dashboards/recent_table_component.html.haml",
    "app/components/iron_admin/dashboards/stats_grid_component.rb",
    "app/components/iron_admin/dashboards/stats_grid_component/stat_component.html.haml",
  ].freeze

  # Utilities whose value is a color.
  UTILITY = "(?:bg|text|border(?:-[xytrblse])?|divide|(?:inset-)?ring(?:-offset)?|outline|placeholder|fill|stroke|" \
            "from|via|to|(?:inset-|drop-)?shadow|decoration|accent|caret)"
  PALETTE = "(?:(?:slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|" \
            "indigo|violet|purple|fuchsia|pink|rose)-(?:50|[1-9]00|950)|white|black)"
  # "#" is escaped for the /x patterns below, where it would start a comment.
  COLOR_LITERAL = "(?:\\#\\h{3,8}(?!\\h)|(?<![a-z])(?:rgba?|hsla?|hwb|lab|lch|oklab|oklch|color)\\()"
  # A palette color with an optional opacity, or an arbitrary value holding a color literal.
  VALUE = "(?:#{PALETTE}(?:/(?:\\d+|\\[[^\\]\\s]+\\]|\\([^)\\s]+\\)))?|\\[[^\\]\\s]*?#{COLOR_LITERAL}[^\\]\\s]*\\])".freeze
  VARIANT = "(?:[\\w-]*\\[[^\\]\\s]*\\]|[\\w-]+(?:/[\\w-]+)?):"
  COLOR_CLASS = /(?<![\w-])(?:#{VARIANT})*!?#{UTILITY}-#{VALUE}!?(?![\w-])/

  NAMED_COLOR = "\\b(?:white|black|red|green|blue|yellow|orange|purple|pink|gray|grey|silver|navy|maroon|olive|" \
                "teal|aqua|fuchsia|lime)\\b"
  STYLE_VALUE = "(?:#{COLOR_LITERAL}|#{NAMED_COLOR})".freeze
  # A CSS declaration of a color property in an inline style.
  STYLE_COLOR = /(?<![\w-])(?:color|background(?:-color)?|border(?:-[a-z]+)*|outline(?:-color)?|fill|stroke|
                 (?:box|text)-shadow|caret-color|accent-color|text-decoration(?:-color)?)\s*:\s*[^;"'}]*?#{STYLE_VALUE}/x
  # A color assigned to an element's style from JavaScript.
  SCRIPT_STYLE_COLOR = /\.style\.\w*(?:[cC]olor|background|fill|stroke|[sS]hadow)\s*=\s*["'`][^"'`]*?#{STYLE_VALUE}|
                        \.setProperty\(\s*["'][\w-]*color["']\s*,\s*["'][^"']*?#{STYLE_VALUE}/x
  # A hex color in an inline SVG (such as a data URI in a style), "#" maybe written as %23.
  SVG_COLOR = /(?<![\w-])(?:fill|stroke|stop-color)=(?:['"]|%2[27])(?:%23|#)\h{3,8}(?!\h)/i

  module_function

  # @return [Array<String>] "path:line: class" for every hard-coded color in the line
  def offenses(path, line, number)
    found = line.scan(COLOR_CLASS) + line.scan(SVG_COLOR)
    found += line.scan(STYLE_COLOR) if line.match?(/\bstyle\b/)
    found += line.scan(SCRIPT_STYLE_COLOR) if path.end_with?(".js")
    found.map { |offense| "#{path}:#{number}: #{offense.strip}" }
  end
end

RSpec.describe ThemeHardcodedColors do
  let(:root) { IronAdmin::Engine.root }
  let(:sources) { root.glob("app/**/*.{haml,erb,rb,js}").map { |path| path.relative_path_from(root).to_s }.sort }

  def offenses_in(path)
    root.join(path).readlines.each_with_index.flat_map { |line, index| described_class.offenses(path, line, index + 1) }
  end

  describe "app sources" do
    subject(:offenses) { (sources - described_class::PENDING).flat_map { |path| offenses_in(path) } }

    it "take every color from the theme" do
      expect(offenses).to be_empty
    end
  end

  describe "PENDING" do
    it "lists only files that exist" do
      expect(described_class::PENDING - sources).to be_empty
    end

    it "lists only files that still hard-code a color, so migrated files leave it" do
      expect(described_class::PENDING.select { |path| offenses_in(path).empty? }).to be_empty
    end
  end

  describe ".offenses" do
    subject(:found) { described_class.offenses(path, line, 7).map { |offense| offense.delete_prefix("#{path}:7: ") } }

    let(:path) { "app/views/example.html.haml" }

    {
      %(%div.bg-gray-50.p-4) => ["bg-gray-50"],
      %(class: "p-2 hover:text-indigo-700") => ["hover:text-indigo-700"],
      %(class: "md:dark:group-hover:border-zinc-800/50") => ["md:dark:group-hover:border-zinc-800/50"],
      %(class: "[&>svg]:fill-white text-black") => ["[&>svg]:fill-white", "text-black"],
      %(class: "bg-[#fafafa] text-[rgb(0,0,0)]") => ["bg-[#fafafa]", "text-[rgb(0,0,0)]"],
      %(class: "shadow-[0_1px_2px_rgba(0,0,0,0.05)]") => ["shadow-[0_1px_2px_rgba(0,0,0,0.05)]"],
      %(class: "!ring-red-500 focus:outline-blue-600!") => ["!ring-red-500", "focus:outline-blue-600!"],
      %(class: "border-b-slate-200 divide-y divide-stone-100") => ["border-b-slate-200", "divide-stone-100"],
      %(class: "placeholder:text-gray-400 from-sky-500 to-white") => ["placeholder:text-gray-400", "from-sky-500", "to-white"],
      %(%span{ style: "color: #fff" }) => ["color: #fff"],
      %(%span{ style: "background-color: rgb(0, 0, 0); width: 2px" }) => ["background-color: rgb("],
      %(%div{ style: "border: 1px solid red" }) => ["border: 1px solid red"],
      %("viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-width='1.5'") => ["stroke='%236b7280"],
    }.each do |source, classes|
      context "with #{source}" do
        let(:line) { source }

        it "finds #{classes.join(", ")}" do
          expect(found).to eq(classes)
        end
      end
    end

    [
      %(class: "text-current bg-transparent border-transparent fill-current stroke-current text-inherit"),
      %(class: "text-sm text-left border border-2 ring-1 ring-inset outline-none shadow-xs divide-y"),
      %(class: "font-[family-name:Inter,sans-serif] text-[13px] bg-[url(/a.svg)]"),
      %(class: "\#{theme.card_bg} \#{theme.border_width} \#{theme.card_border}"),
      %(%div{ style: "height: \#{height}px; position: relative;" }),
      %(%span{ style: "background-color: \#{value}" }),
      %(color: "red" # a Ruby keyword, not a style),
      %("%3cpath fill='currentColor' stroke='none'"),
      %(# Renders the to-do list and the bg-image),
    ].each do |source|
      context "with #{source}" do
        let(:line) { source }

        it "finds nothing" do
          expect(found).to be_empty
        end
      end
    end

    context "with JavaScript" do
      let(:path) { "app/javascript/iron_admin/controllers/example_controller.js" }

      {
        %(this.element.style.backgroundColor = "#e5e7eb") => [%(.style.backgroundColor = "#e5e7eb)],
        %(el.style.setProperty("--x-color", "rgb(1, 2, 3)")) => [%[.setProperty("--x-color", "rgb(]],
        %(this.element.classList.add("bg-indigo-50")) => ["bg-indigo-50"],
      }.each do |source, classes|
        context "with #{source}" do
          let(:line) { source }

          it "finds #{classes.join(", ")}" do
            expect(found).to eq(classes)
          end
        end
      end

      context "with a color read from the theme" do
        let(:line) { %(this.element.style.color = this.colorValue) }

        it "finds nothing" do
          expect(found).to be_empty
        end
      end
    end
  end
end
