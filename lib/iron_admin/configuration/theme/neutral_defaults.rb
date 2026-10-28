# frozen_string_literal: true

# The values of the built-in Neutral look. Theme#initialize calls these methods, so every new
# theme starts with them; each property of the theme gets its Neutral value here.

module IronAdmin
  class Configuration
    class Theme
      private

      def init_control_defaults
        @btn_primary = "bg-zinc-900 text-white hover:bg-zinc-700 " \
                       "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500"
        @btn_secondary = "bg-white text-zinc-900 border border-zinc-200 hover:bg-zinc-50 hover:border-zinc-300"
        @btn_danger = "bg-red-600 text-white hover:bg-red-700"
        @btn_ghost = "bg-transparent text-zinc-700 hover:bg-zinc-100 hover:text-zinc-900"
        @link = "text-indigo-600 hover:text-indigo-700"
        @link_muted = "text-zinc-500 hover:text-zinc-900"
        @focus_ring = "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500"
        @control_radius = "rounded-md"
        @control_shadow = "shadow-xs"
      end

      def init_form_defaults
        @input_border = "border-zinc-200 hover:border-zinc-300"
        @input_focus = "focus:border-indigo-500 focus:ring-3 focus:ring-indigo-500/15"
        @checkbox_checked = "checked:border-indigo-600 checked:bg-indigo-600 focus:ring-3 focus:ring-indigo-500/15"
        @checkbox_border = "border-zinc-500"
        @checkbox_radius = "rounded-sm"
        @input_error = "border-red-400 focus:border-red-500 focus:ring-3 focus:ring-red-500/20"
        @placeholder_text = "placeholder:text-zinc-500"
        @disabled_text = "text-zinc-300"
      end

      def init_navigation_defaults
        @scope_active = "border-zinc-900 text-zinc-900"
        @scope_inactive = "border-transparent text-zinc-500 hover:text-zinc-900 hover:border-zinc-300"
        @badge_count = "bg-zinc-100 text-zinc-700"
        @sidebar_bg = "bg-zinc-50"
        @sidebar_border = "lg:border-r border-zinc-200"
        @sidebar_title = "text-zinc-900"
        @sidebar_link = "text-zinc-600"
        @sidebar_link_hover = "hover:bg-zinc-200/60 hover:text-zinc-900"
        @sidebar_link_active = "bg-white text-zinc-900 shadow-xs ring-1 ring-zinc-200 before:absolute before:left-0 " \
                               "before:inset-y-2 before:w-0.5 before:rounded-full before:bg-indigo-500"
        @sidebar_group_label = "text-zinc-500"
        @navbar_bg = "bg-white"
        @navbar_border = "border-zinc-200"
        @navbar_search_bg = "bg-zinc-50"
        @navbar_search_focus_bg = "focus:bg-white"
        @navbar_text = "text-zinc-600"
        @kbd = "border-zinc-200 bg-white text-zinc-500"
        @skip_link = "focus:bg-white focus:text-zinc-900 focus:ring-2 focus:ring-indigo-500"
      end

      def init_surface_defaults
        @table_header_bg = "bg-zinc-50"
        @table_header_text = "text-xs font-medium text-zinc-500"
        @table_cell_padding = "px-4 py-2.5"
        @table_frame = ""
        @table_sticky_shadow = "shadow-[-4px_0_6px_-4px_rgba(0,0,0,0.08)]"
        @table_row_hover = "hover:bg-zinc-50"
        @table_sticky_row_hover = ""
        @table_border = "divide-zinc-200"
        @table_head_border = ""
        @card_bg = "bg-white"
        @card_border = "border-zinc-200"
        @card_shadow = "shadow-xs"
        @popover_shadow = "shadow-lg"
        @popover_bg = ""
        @card_title = "text-sm font-semibold text-zinc-900"
        @main_bg = "bg-zinc-50"
        @border_radius = "rounded-lg"
        @border_width = "border"
        @color_scheme = "light"
        @swatch = "bg-white ring-1 ring-inset ring-zinc-300"
        @surface_muted = "bg-zinc-50"
        @item_hover = "hover:bg-zinc-100"
        @item_active = "bg-zinc-100"
        @icon_muted = "text-zinc-400"
        @overlay_bg = "bg-zinc-900/40"
      end

      def init_typography_defaults
        @font_family = "font-[family-name:Inter,ui-sans-serif,system-ui,sans-serif]"
        @font_stylesheet_url = "https://fonts.googleapis.com/css2?family=Inter:wght@400..700&display=swap"
        @heading_font = ""
        @heading_weight = "font-semibold"
        @page_title = "text-xl font-semibold tracking-tight text-zinc-900"
        @label_transform = ""
        @field_label_transform = ""
        @body_text = "text-zinc-900"
        @muted_text = "text-zinc-500"
        @label_text = "text-zinc-700"
        @error_text = "text-red-600"
        @success_text = "text-emerald-700"
      end

      def init_feedback_defaults
        @badge_shape = "rounded-md font-medium"
        @chip = "bg-zinc-100 text-zinc-700 ring-1 ring-inset ring-zinc-200"
        @danger_item = "text-red-600 hover:bg-red-50 hover:text-red-700"
        @tooltip = "bg-zinc-900 text-white"
        @code_block = "bg-zinc-950 text-zinc-100"
        @progress_track = "bg-zinc-200"
        @pagination_active = "bg-zinc-900 text-white border-zinc-900"
        @metric_label = "text-xs font-medium text-zinc-500"
        @metric_value = "text-2xl font-semibold tracking-tight tabular-nums text-zinc-900"
        @metric_icon = "bg-zinc-100 text-zinc-500"
      end

      def init_palette_defaults
        @alert_palette = {
          success: "bg-emerald-50 border-emerald-200 text-emerald-800",
          error: "bg-red-50 border-red-200 text-red-800",
          warning: "bg-amber-50 border-amber-200 text-amber-800",
          info: "bg-blue-50 border-blue-200 text-blue-800",
        }
        @badge_palette = {
          green: "bg-emerald-50 text-emerald-700 ring-1 ring-inset ring-emerald-600/20",
          red: "bg-red-50 text-red-700 ring-1 ring-inset ring-red-600/10",
          yellow: "bg-amber-50 text-amber-800 ring-1 ring-inset ring-amber-600/20",
          blue: "bg-blue-50 text-blue-700 ring-1 ring-inset ring-blue-700/10",
          indigo: "bg-indigo-50 text-indigo-700 ring-1 ring-inset ring-indigo-700/10",
          purple: "bg-purple-50 text-purple-700 ring-1 ring-inset ring-purple-700/10",
          pink: "bg-pink-50 text-pink-700 ring-1 ring-inset ring-pink-700/10",
          orange: "bg-orange-50 text-orange-800 ring-1 ring-inset ring-orange-600/20",
          teal: "bg-teal-50 text-teal-700 ring-1 ring-inset ring-teal-600/20",
          gray: "bg-zinc-50 text-zinc-600 ring-1 ring-inset ring-zinc-500/10",
        }
        @badge_dot_palette = {
          green: "bg-emerald-500",
          red: "bg-red-500",
          yellow: "bg-amber-500",
          blue: "bg-blue-500",
          indigo: "bg-indigo-500",
          purple: "bg-purple-500",
          pink: "bg-pink-500",
          orange: "bg-orange-500",
          teal: "bg-teal-500",
          gray: "bg-zinc-400",
        }
      end

      def init_chart_defaults
        @chart_colors = %w[
          rgba(99,102,241,0.85) rgba(14,165,233,0.85) rgba(16,185,129,0.85)
          rgba(245,158,11,0.85) rgba(244,63,94,0.85) rgba(139,92,246,0.85)
        ]
        @chart_border_color = "rgb(99, 102, 241)"
        @chart_grid_color = "rgba(228, 228, 231, 1)"
        @chart_text_color = "rgb(113, 113, 122)"
      end
    end
  end
end
