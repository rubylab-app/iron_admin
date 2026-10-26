# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Engine do
  describe "config/importmap.rb" do
    subject(:pinned_modules) { engine_importmap.packages.keys }

    let(:engine_importmap) { Importmap::Map.new.draw(described_class.root.join("config/importmap.rb")) }
    let(:javascript_root) { described_class.root.join("app/javascript") }
    let(:javascript_files) { javascript_root.glob("iron_admin/**/*.js") }

    # Pinned by the host app (the stimulus-rails installer), not by the engine.
    let(:host_pinned_modules) { %w[@hotwired/stimulus] }

    # Every bare specifier in a static `import ... from "x"` or `import "x"`.
    let(:imported_modules) do
      javascript_files.flat_map do |file|
        file.read.scan(/^\s*import\s+(?:[^"';]+?\s+from\s+)?["']([^"']+)["']/).flatten
      end.uniq
    end

    # Module names as the engine's JavaScript imports them:
    # iron_admin/index.js is "iron_admin", the rest keep their path.
    let(:shipped_modules) do
      javascript_files.map do |file|
        file.relative_path_from(javascript_root).sub_ext("").to_s.delete_suffix("/index")
      end
    end

    it "pins every module imported by the engine's JavaScript" do
      expect(imported_modules - host_pinned_modules - pinned_modules).to be_empty
    end

    it "pins every JavaScript file shipped under app/javascript/iron_admin" do
      expect(shipped_modules - pinned_modules).to be_empty
    end

    it "points every IronAdmin pin at a file under app/javascript" do
      engine_paths = engine_importmap.packages.values.map(&:path).grep(%r{\Airon_admin/})

      expect(engine_paths).to all(satisfy { |path| javascript_root.join(path).file? })
    end

    it "adds its pins to the host application's import map" do
      expect(Rails.application.importmap.packages.keys).to include(*pinned_modules)
    end
  end

  describe "app/javascript/iron_admin/index.js" do
    subject(:registrations) do
      described_class.root.join("app/javascript/iron_admin/index.js").read
        .scan(/^application\.register\("([\w-]+)", (\w+)\)$/).to_h
    end

    # cp_color_field_controller.js => "cp-color-field" => CpColorFieldController
    let(:controllers) do
      described_class.root.glob("app/javascript/iron_admin/controllers/*_controller.js").to_h do |file|
        name = file.basename(".js").to_s
        [name.delete_suffix("_controller").dasherize, name.camelize]
      end
    end

    it "registers every shipped Stimulus controller under its file-name identifier" do
      expect(registrations).to include(controllers)
    end
  end
end
