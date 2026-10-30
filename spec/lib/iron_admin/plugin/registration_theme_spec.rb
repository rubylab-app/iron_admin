# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Plugin::Registration do
  def plugin_named(name, &setup_block)
    Class.new(IronAdmin::Plugin) do
      plugin_name name
      setup(&setup_block) if setup_block
    end
  end

  def theme_plugin(name, theme_name: :harbor, label: "Harbor", &customization)
    plugin_named(name) do |admin|
      admin.theme(theme_name, label: label, &customization)
    end
  end

  def harbor
    IronAdmin.configuration.find_theme(:harbor)
  end

  describe "#theme" do
    it "returns the registered theme" do
      theme = described_class.new(plugin_named("harbor_theme")).theme(:harbor)

      expect(theme).to equal(IronAdmin.configuration.find_theme(:harbor))
    end

    it "labels the theme from its name" do
      described_class.new(plugin_named("night")).theme(:late_night)

      expect(IronAdmin.configuration.find_theme(:late_night).label).to eq("Late Night")
    end

    it "keeps a label that is not the titleized name" do
      described_class.new(plugin_named("harbor_theme")).theme(:harbor, label: "Deep Harbor")

      expect(harbor.label).to eq("Deep Harbor")
    end

    context "when a plugin registers a theme" do
      before { IronAdmin.register_plugin(IronAdmin::Theme::HighContrast) }

      it "adds the theme" do
        expect(IronAdmin.configuration.themes.keys).to include(:high_contrast)
      end

      it "keeps the values the block sets" do
        expect(IronAdmin.configuration.find_theme(:high_contrast).btn_primary).to eq("plugin-theme-primary")
      end
    end

    context "when the default theme was customized" do
      before do
        IronAdmin.configuration.theme { |theme| theme.main_bg = "bg-blue-600" }
        IronAdmin.register_plugin(IronAdmin::Theme::HighContrast)
      end

      it "starts from the Neutral values" do
        neutral = IronAdmin::Configuration::Theme.new

        expect(IronAdmin.configuration.find_theme(:high_contrast).main_bg).to eq(neutral.main_bg)
      end
    end

    context "when the plugin activates again" do
      it "does not yield the theme again" do
        calls = 0
        plugin = theme_plugin("harbor_theme") do |theme|
          calls += 1
          theme.btn_primary = "from-plugin"
        end
        IronAdmin.register_plugin(plugin)

        IronAdmin::PluginRegistry.activate_all!

        expect(calls).to eq(1)
      end

      it "keeps the theme object" do
        IronAdmin.register_plugin(theme_plugin("harbor_theme"))
        theme = harbor

        IronAdmin::PluginRegistry.activate_all!

        expect(harbor).to equal(theme)
      end

      it "keeps an adjustment the app made" do
        IronAdmin.register_plugin(theme_plugin("harbor_theme") { |theme| theme.btn_primary = "from-plugin" })
        harbor.btn_primary = "from-app"

        IronAdmin::PluginRegistry.activate_all!

        expect(harbor.btn_primary).to eq("from-app")
      end

      it "keeps the label the first registration set" do
        IronAdmin.register_plugin(theme_plugin("harbor_theme", label: "First"))

        IronAdmin.register_plugin(theme_plugin("harbor_theme", label: "Second"))

        expect(harbor.label).to eq("First")
      end

      it "returns the same theme" do
        plugin = theme_plugin("harbor_theme")
        IronAdmin.register_plugin(plugin)
        theme = harbor

        expect(described_class.new(plugin).theme(:harbor)).to equal(theme)
      end
    end

    context "when another class declares the same plugin_name" do
      before { IronAdmin.register_plugin(theme_plugin("shared") { |theme| theme.btn_primary = "first" }) }

      it "keeps the theme object" do
        theme = harbor

        IronAdmin.register_plugin(theme_plugin("shared") { |theme| theme.btn_primary = "second" })

        expect(harbor).to equal(theme)
      end

      it "keeps the first plugin's values" do
        IronAdmin.register_plugin(theme_plugin("shared") { |theme| theme.btn_primary = "second" })

        expect(harbor.btn_primary).to eq("first")
      end
    end

    context "when another plugin registered the name" do
      before { IronAdmin.register_plugin(theme_plugin("first") { |theme| theme.btn_primary = "first" }) }

      it "raises PluginError naming the theme and both plugins" do
        expect { IronAdmin.register_plugin(theme_plugin("second")) }.to raise_error(
          IronAdmin::PluginError,
          'Cannot register theme :harbor for plugin "second": plugin "first" already registered it. ' \
          "Rename one theme, or remove one registration."
        )
      end

      it "does not run the second block" do
        called = false

        expect { IronAdmin.register_plugin(theme_plugin("second") { called = true }) }
          .to raise_error(IronAdmin::PluginError)
        expect(called).to be(false)
      end

      it "keeps the first theme" do
        expect { IronAdmin.register_plugin(theme_plugin("second") { |theme| theme.btn_primary = "second" }) }
          .to raise_error(IronAdmin::PluginError)

        expect(harbor.btn_primary).to eq("first")
      end
    end

    context "when an initializer registered the theme before the plugin activates" do
      before do
        IronAdmin.configure do |config|
          config.register_theme(:harbor, label: "Harbor") { |theme| theme.btn_primary = "from-app" }
        end
      end

      it "raises PluginError naming the theme, the plugin and the app" do
        expect { IronAdmin.register_plugin(theme_plugin("harbor_theme")) }.to raise_error(
          IronAdmin::PluginError,
          'Cannot register theme :harbor for plugin "harbor_theme": the app already registered it. ' \
          "Rename one theme, or remove one registration."
        )
      end

      it "keeps the app theme" do
        expect { IronAdmin.register_plugin(theme_plugin("harbor_theme") { |theme| theme.btn_primary = "from-plugin" }) }
          .to raise_error(IronAdmin::PluginError)

        expect(harbor.btn_primary).to eq("from-app")
      end
    end

    context "when the plugin registers Neutral" do
      it "raises PluginError because the app owns Neutral" do
        expect { described_class.new(plugin_named("skin")).theme(:neutral) }.to raise_error(
          IronAdmin::PluginError,
          'Cannot register theme :neutral for plugin "skin": the app already registered it. ' \
          "Rename one theme, or remove one registration."
        )
      end
    end

    context "when the block raises" do
      before do
        broken = plugin_named("broken") { |admin| admin.theme(:harbor) { raise "boom" } }
        IronAdmin.register_plugin(broken)
      rescue RuntimeError => e
        raise unless e.message == "boom"
      end

      it "leaves no theme" do
        expect(harbor).to be_nil
      end

      it "leaves the name free for another plugin" do
        IronAdmin.register_plugin(theme_plugin("later", label: "Later"))

        expect(harbor.label).to eq("Later")
      end
    end

    context "when the name is a String" do
      let(:registration) { described_class.new(plugin_named("case_theme")) }

      before { registration.theme("Harbor", label: "Deep Harbor") }

      it "stores the downcased name" do
        expect(IronAdmin.configuration.themes.keys).to include(:harbor)
      end

      it "finds the theme by another case" do
        expect(IronAdmin.configuration.find_theme("HARBOR")).to equal(harbor)
      end

      it "finds the theme by Symbol" do
        expect(IronAdmin.configuration.find_theme(:harbor)).to equal(harbor)
      end
    end

    context "when the app registered the name in another case" do
      before { IronAdmin.configuration.register_theme(:harbor) }

      it "treats that key as taken" do
        expect { described_class.new(plugin_named("other")).theme("Harbor") }.to raise_error(
          IronAdmin::PluginError, /theme :harbor/
        )
      end
    end
  end
end
