# frozen_string_literal: true

module IronAdmin
  module Form
    # Tailwind classes of form controls. Colors, borders, radii and shadows come
    # from the theme; each state swaps classes instead of adding a second class
    # for the same CSS property.
    #
    # @example An input with an error
    #   ControlClasses.input(theme, error: true)
    module ControlClasses
      # Horizontal padding of a text input without an icon or a prefix.
      # @return [String]
      INPUT_PADDING = "px-3"

      # @return [String]
      TRANSITION = "transition duration-150 ease-in-out"

      module_function

      # @param theme [IronAdmin::Configuration::Theme]
      # @param error [Boolean] Whether the value failed validation
      # @param muted [Boolean] Readonly or disabled
      # @param padding [String] Horizontal padding, such as "pl-9 pr-3" beside an icon
      # @return [String] Classes of a one-line text input, 36px high
      def input(theme, error: false, muted: false, padding: INPUT_PADDING)
        "block w-full h-9 #{padding} text-sm outline-hidden #{TRANSITION} " \
        "#{field_box(theme, error:, muted:)} #{theme.placeholder_text}".squish
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @param error [Boolean] Whether the value failed validation
      # @param muted [Boolean] Readonly or disabled
      # @return [String] Classes of a textarea, as high as its rows
      def textarea(theme, error: false, muted: false)
        "block w-full px-3 py-2 text-sm resize-y outline-hidden #{TRANSITION} " \
        "#{field_box(theme, error:, muted:)} #{theme.placeholder_text}".squish
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @param error [Boolean] Whether the value failed validation
      # @param muted [Boolean] Disabled
      # @return [String] Classes of a select, 36px high, with the engine's chevron
      def select(theme, error: false, muted: false)
        "block w-full h-9 appearance-none pl-3 pr-9 text-sm outline-hidden cp-select-chevron #{TRANSITION} " \
        "#{field_box(theme, error:, muted:)}".squish
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @param error [Boolean] Whether the upload failed validation
      # @return [String] Classes of a file input, 36px high; a line in the input's border color sets off its button
      def file_input(theme, error: false)
        "block w-full h-9 pl-1 pr-3 py-1 text-sm cursor-pointer outline-hidden #{TRANSITION} " \
        "file:mr-3 file:h-7 file:px-3 file:border-r file:border-inherit file:text-sm file:font-medium " \
        "file:cursor-pointer #{field_box(theme, error:)}".squish
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] Classes of a checkbox with the engine's check mark
      def checkbox(theme)
        "h-4 w-4 shrink-0 appearance-none cursor-pointer cp-checkbox-mark #{TRANSITION} " \
        "disabled:cursor-not-allowed disabled:opacity-50 #{theme.checkbox_radius} #{toggle_box(theme)}".squish
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @return [String] Classes of a radio button with the engine's dot
      def radio(theme)
        "h-4 w-4 shrink-0 appearance-none rounded-full cursor-pointer cp-radio-mark #{TRANSITION} " \
        "disabled:cursor-not-allowed disabled:opacity-50 #{toggle_box(theme)}".squish
      end

      # @param theme [IronAdmin::Configuration::Theme]
      # @param variant [Symbol] :primary, :secondary, :danger or :ghost
      # @return [String] Classes of a button, or a link styled as one, 36px high
      # @raise [ArgumentError] For an unknown variant
      def button(theme, variant = :primary)
        "inline-flex h-9 shrink-0 items-center justify-center gap-2 px-3.5 text-sm font-medium whitespace-nowrap " \
        "cursor-pointer #{TRANSITION} disabled:pointer-events-none disabled:opacity-50 " \
        "#{theme.control_radius} #{button_colors(theme, variant)}".squish
      end

      # An error swaps the border and focus classes; a muted control swaps the background.
      def field_box(theme, error: false, muted: false)
        state = error ? theme.input_error : "#{theme.input_border} #{theme.input_focus}"
        background = muted ? "#{theme.surface_muted} cursor-not-allowed" : theme.card_bg
        "#{theme.control_radius} #{theme.border_width} #{state} #{background} #{theme.body_text} #{theme.control_shadow}"
      end

      # checkbox_border, not input_border: a hover border color would cover the checked one.
      def toggle_box(theme)
        "#{theme.border_width} #{theme.checkbox_border} #{theme.card_bg} #{theme.control_shadow} #{theme.checkbox_checked}"
      end

      # btn_primary carries its own focus outline; the other variants take the theme's focus ring.
      def button_colors(theme, variant)
        case variant
        when :primary then "#{theme.btn_primary} #{theme.control_shadow}"
        when :secondary then "#{theme.btn_secondary} #{theme.control_shadow} #{theme.focus_ring}"
        when :danger then "#{theme.btn_danger} #{theme.control_shadow} #{theme.focus_ring}"
        when :ghost then "#{theme.btn_ghost} #{theme.focus_ring}"
        else raise ArgumentError, "Unknown button variant: #{variant.inspect}"
        end
      end

      private_class_method :field_box, :toggle_box, :button_colors
    end
  end
end
