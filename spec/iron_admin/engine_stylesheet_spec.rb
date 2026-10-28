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

    it "draws the toolbar icons light under a dark color scheme" do
      expect(unlayered).to match(/\.scheme-dark trix-toolbar \.trix-button--icon::before\s*\{\s*filter:\s*invert\(1\);/)
    end
  end
end
