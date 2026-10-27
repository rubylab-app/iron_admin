# frozen_string_literal: true

require "rails_helper"

# Pages render with the theme resolved for the request, so templates, helpers
# and components read IronAdmin.current_theme, never the default theme.
RSpec.describe IronAdmin::Engine do
  describe "theme reads in app and lib sources" do
    subject(:reads) do
      sources.flat_map do |path|
        File.readlines(path).each_with_index.filter_map do |line, index|
          "#{path.relative_path_from(described_class.root)}:#{index + 1}: #{line.strip}" if line.match?(/configuration\.theme\b/)
        end
      end
    end

    let(:sources) { described_class.root.glob("{app,lib}/**/*.{haml,erb,rb}") }

    it "use IronAdmin.current_theme" do
      expect(reads).to be_empty
    end
  end
end
