# frozen_string_literal: true

require "rails_helper"

# Pages render with the theme resolved for the request, so templates, helpers
# and components read IronAdmin.current_theme, never the default theme.
RSpec.describe IronAdmin::Engine do
  let(:default_theme_read) { /configuration\.theme(?:_config)?\b/ }

  describe "theme reads in app and lib sources" do
    subject(:reads) do
      sources.flat_map do |path|
        File.readlines(path).each_with_index.filter_map do |line, index|
          "#{path.relative_path_from(described_class.root)}:#{index + 1}: #{line.strip}" if line.match?(default_theme_read)
        end
      end
    end

    let(:sources) { described_class.root.glob("{app,lib}/**/*.{haml,erb,rb}") }

    it "use IronAdmin.current_theme" do
      expect(reads).to be_empty
    end
  end

  describe "default theme reads" do
    # theme_config is an alias of Configuration#theme, the default theme.
    %w[IronAdmin.configuration.theme.card_bg IronAdmin.configuration.theme_config.card_bg].each do |read|
      it "include #{read}" do
        expect(read).to match(default_theme_read)
      end
    end

    %w[IronAdmin.configuration.theme_for(name) IronAdmin.configuration.themes configuration.resolve_theme(request)].each do |read|
      it "leave out #{read}" do
        expect(read).not_to match(default_theme_read)
      end
    end
  end
end
