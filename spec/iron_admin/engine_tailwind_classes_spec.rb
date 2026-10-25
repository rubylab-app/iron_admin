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
  end
end
