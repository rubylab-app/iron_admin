# frozen_string_literal: true

require "rails_helper"

# Host apps compile these sources with Tailwind CSS v4 (see engine.css).
# Tailwind silently skips classes it does not know, so the element renders unstyled.
RSpec.describe IronAdmin::Engine do
  describe "Tailwind CSS classes in app and lib sources" do
    subject(:offenses) do
      sources.flat_map do |path|
        File.readlines(path).each_with_index.filter_map do |line, index|
          "#{path.relative_path_from(described_class.root)}:#{index + 1}: #{line.strip}" if line.match?(pattern)
        end
      end
    end

    let(:sources) { described_class.root.glob("{app,lib}/**/*.{haml,erb,rb}") }

    {
      "*-opacity-* utilities (use a color/opacity modifier such as bg-gray-900/50)" =>
        /\b(?:bg|text|border|ring|divide|placeholder)-opacity-\d/,
      "flex-grow and flex-shrink (use grow and shrink)" => /(?<![\w-])flex-(?:grow|shrink)\b/,
      "overflow-ellipsis (use text-ellipsis)" => /(?<![\w-])overflow-ellipsis\b/,
      "decoration-slice and decoration-clone (use box-decoration-slice and box-decoration-clone)" =>
        /(?<![\w-])decoration-(?:slice|clone)\b/,
    }.each do |utility, removed|
      context "with #{utility}, which Tailwind v4 removed" do
        let(:pattern) { removed }

        it "uses none of them" do
          expect(offenses).to be_empty
        end
      end
    end

    context "with an important modifier placed before the variants" do
      # `!focus:border-red-500` generates no CSS; write `focus:!border-red-500`.
      let(:pattern) { /(?<![\w:!-])!(?:[a-z0-9-]+:)+[a-z]/ }

      it "uses none of them" do
        expect(offenses).to be_empty
      end
    end

    context "with a fractional value in the HAML class shorthand" do
      # HAML ends a shorthand class at the dot, so `.gap-1.5` renders the classes
      # "gap-1" and "5"; write fractional values in a class attribute.
      let(:sources) { described_class.root.glob("app/**/*.haml") }
      let(:pattern) { /^\s*(?:%[\w:-]+|[.#][\w:-]+)(?:[.#][\w:-]+)*?\.\d+(?![\w:-])/ }

      it "uses none of them" do
        expect(offenses).to be_empty
      end
    end

    context "with an arbitrary value split across string literals" do
      # Tailwind reads `bg-[url(...)]` only as one unbroken token; a value that
      # continues in the next literal generates no CSS.
      let(:pattern) { /[\w)]-\[[^\]"]*"\s*\\?$/ }

      it "uses none of them" do
        expect(offenses).to be_empty
      end
    end
  end

  describe "Inline SVG backgrounds in engine.css" do
    let(:engine_css) { described_class.root.join("app/assets/tailwind/iron_admin/engine.css").read }

    {
      "cp-select-chevron" => /\.cp-select-chevron\s*\{[^}]*background-image:\s*url\("data:image.svg\+xml/,
      "cp-checkbox-mark" => /\.cp-checkbox-mark:checked\s*\{[^}]*background-image:\s*url\("data:image.svg\+xml/,
      "cp-radio-mark" => /\.cp-radio-mark:checked\s*\{[^}]*background-image:\s*url\("data:image.svg\+xml/,
      "cp-select-chevron under a dark color scheme" =>
        /\.scheme-dark \.cp-select-chevron\s*\{[^}]*background-image:\s*url\("data:image.svg\+xml/,
    }.each do |name, rule|
      it "styles #{name}" do
        expect(engine_css).to match(rule)
      end
    end
  end

  describe "Tailwind CSS source scanning in engine.css" do
    subject(:unscanned) { sources.reject { |path| globs.any? { |glob| path.fnmatch?(glob, File::FNM_PATHNAME) } } }

    let(:engine_css) { described_class.root.join("app/assets/tailwind/iron_admin/engine.css") }
    let(:globs) do
      engine_css.read.scan(/^@source "([^"]+)";/).flatten.map { |glob| engine_css.dirname.join(glob).cleanpath.to_s }
    end

    context "with the JavaScript controllers, which toggle classes such as opacity-50" do
      let(:sources) { described_class.root.glob("app/javascript/**/*.js") }

      it "scans every file" do
        expect(unscanned).to be_empty
      end
    end
  end
end
