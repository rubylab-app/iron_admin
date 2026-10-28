# frozen_string_literal: true

require "rails_helper"

# Trix's stylesheet is not in a cascade layer, so only rules outside @layer can win over it.
RSpec.describe IronAdmin::Engine do
  describe "app/assets/tailwind/iron_admin/engine.css" do
    subject(:unlayered) do
      depth = 0
      layered = false
      css.each_char.with_object(+"") do |char, outside|
        if char == "{"
          layered = true if depth.zero? && outside.end_with?(*layer_openers)
          depth += 1
        elsif char == "}"
          depth -= 1
          layered = false if depth.zero?
        end
        outside << char unless layered
      end
    end

    let(:css) { described_class.root.join("app/assets/tailwind/iron_admin/engine.css").read.gsub(%r{^\s*/\*.*?\*/}m, "") }
    let(:layer_openers) { ["@layer components ", "@layer components"] }

    it "hands the border of a themed rich text editor back to the theme's classes" do
      expect(unlayered).to match(/trix-editor\.cp-rich-text\s*\{[^}]*border:\s*revert-layer;[^}]*border-radius:\s*revert-layer;/)
    end

    it "wraps the rich text toolbar's buttons onto more rows, where Trix would scroll them out of reach" do
      expect(unlayered).to match(/\.cp-rich-text-field trix-toolbar \.trix-button-row\s*\{[^}]*flex-wrap:\s*wrap;[^}]*overflow-x:\s*visible;/)
    end

    it "spaces the wrapped button groups evenly instead of with Trix's left margin" do
      expect(unlayered).to match(/\.cp-rich-text-field trix-toolbar \.trix-button-group:not\(:first-child\)\s*\{\s*margin-left:\s*0;/)
    end

    # The fade follows a scroll timeline, so it shows only while the frame can scroll that way.
    it "fades the edges of a cp-scroll-fade frame by its sideways scroll" do
      expect(unlayered).to match(/\.cp-scroll-fade\s*\{[^}]*mask-image:[^}]*animation-timeline:\s*scroll\(self inline\);/)
    end

    # A mask also hides the frame's own focus outline, and a focused link near the edge.
    it "lifts the fade while the frame or a control in it has the keyboard focus" do
      expect(unlayered).to match(/\.cp-scroll-fade:focus-visible,\s*\.cp-scroll-fade:has\(:focus-visible\)\s*\{\s*mask-image:\s*none;/)
    end

    it "draws the toolbar icons light under a dark color scheme" do
      expect(unlayered).to match(/\.scheme-dark trix-toolbar \.trix-button--icon::before\s*\{\s*filter:\s*invert\(1\);/)
    end
  end
end
