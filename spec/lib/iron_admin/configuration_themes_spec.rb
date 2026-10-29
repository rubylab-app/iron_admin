# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Configuration do
  subject(:config) { described_class.new }

  let(:neutral) { IronAdmin::Configuration::Theme.new }

  def request_with(cookie: nil)
    env = cookie ? { "HTTP_COOKIE" => "iron_admin_theme=#{cookie}" } : {}
    ActionDispatch::Request.new(Rack::MockRequest.env_for("/admin", env))
  end

  describe "#themes" do
    it "has the Neutral theme" do
      expect(config.themes.keys).to eq([:neutral])
    end

    it "labels the Neutral theme" do
      expect(config.themes[:neutral].label).to eq("Neutral")
    end

    context "with registered themes" do
      before do
        config.register_theme(:midnight)
        config.register_theme(:paper)
      end

      it "lists the default theme first, then the others in registration order" do
        expect(config.themes.keys).to eq(%i[neutral midnight paper])
      end

      context "when default_theme names a theme registered later" do
        before { config.default_theme = :paper }

        it "lists the default theme first" do
          expect(config.themes.keys).to eq(%i[paper neutral midnight])
        end
      end
    end

    it "returns a copy, so changing it registers nothing" do
      config.themes[:midnight] = neutral

      expect(config.themes).not_to have_key(:midnight)
    end
  end

  describe "#register_theme" do
    it "returns the registered theme" do
      theme = config.register_theme(:midnight)

      expect(config.themes[:midnight]).to equal(theme)
    end

    it "yields the theme it registers" do
      yielded = nil
      theme = config.register_theme(:midnight) { |t| yielded = t }

      expect(yielded).to equal(theme)
    end

    it "keeps what the block sets" do
      config.register_theme(:midnight) { |t| t.main_bg = "bg-zinc-950" }

      expect(config.themes[:midnight].main_bg).to eq("bg-zinc-950")
    end

    it "starts from the Neutral values" do
      expect(config.register_theme(:midnight).btn_primary).to eq(neutral.btn_primary)
    end

    it "names the theme with a Symbol" do
      expect(config.register_theme("midnight").name).to eq(:midnight)
    end

    it "labels the theme from its name" do
      expect(config.register_theme(:late_night).label).to eq("Late Night")
    end

    it "accepts a label" do
      expect(config.register_theme(:midnight, label: "Night").label).to eq("Night")
    end

    context "after config.theme customized the default theme" do
      before { config.theme { |t| t.btn_primary = "bg-blue-600 text-white" } }

      it "starts from the Neutral values, not from the customized theme" do
        expect(config.register_theme(:midnight).btn_primary).to eq(neutral.btn_primary)
      end
    end

    context "when the block customizes the new theme" do
      before { config.register_theme(:midnight) { |t| t.chart_colors << "#000000" } }

      it "leaves the default theme as it was" do
        expect(config.theme.chart_colors).to eq(neutral.chart_colors)
      end
    end

    context "with a name already registered" do
      before { config.register_theme(:midnight, label: "Old") }

      it "replaces that theme" do
        config.register_theme(:midnight, label: "New")

        expect(config.themes.values.map(&:label)).to eq(%w[Neutral New])
      end
    end

    [nil, "", "  "].each do |blank|
      context "with the blank name #{blank.inspect}" do
        it "raises ArgumentError" do
          expect { config.register_theme(blank) }.to raise_error(ArgumentError, /name/)
        end
      end
    end
  end

  describe "#default_theme" do
    it "defaults to :neutral" do
      expect(config.default_theme).to eq(:neutral)
    end

    it "stores the name as a Symbol" do
      config.default_theme = "midnight"

      expect(config.default_theme).to eq(:midnight)
    end

    context "with a blank name" do
      it "raises ArgumentError" do
        expect { config.default_theme = "" }.to raise_error(ArgumentError, /name/)
      end
    end
  end

  describe "#theme" do
    it "returns the Neutral theme" do
      expect(config.theme).to equal(config.themes[:neutral])
    end

    it "customizes the theme used when nothing else resolves" do
      config.theme { |t| t.btn_primary = "bg-blue-600 text-white" }

      expect(config.resolve_theme(request_with).btn_primary).to eq("bg-blue-600 text-white")
    end

    context "when default_theme names a registered theme" do
      before do
        config.register_theme(:midnight)
        config.default_theme = :midnight
      end

      it "returns that theme" do
        expect(config.theme).to equal(config.themes[:midnight])
      end
    end

    context "when default_theme names a theme that is not registered" do
      before { config.default_theme = :missing }

      it "returns the Neutral theme" do
        expect(config.theme).to equal(config.themes[:neutral])
      end
    end
  end

  describe "#theme_config" do
    it "is the theme config.theme returns" do
      expect(config.theme_config).to equal(config.theme)
    end
  end

  describe "#find_theme" do
    let!(:midnight) { config.register_theme(:midnight) }

    it "finds a theme by Symbol" do
      expect(config.find_theme(:midnight)).to equal(midnight)
    end

    it "finds a theme by String" do
      expect(config.find_theme("midnight")).to equal(midnight)
    end

    [nil, "", "unknown"].each do |name|
      context "with #{name.inspect}" do
        it "returns nil" do
          expect(config.find_theme(name)).to be_nil
        end
      end
    end
  end

  describe "#theme_for" do
    let!(:midnight) { config.register_theme(:midnight) }

    it "returns the theme registered under the name" do
      expect(config.theme_for("midnight")).to equal(midnight)
    end

    [nil, "", " ", "unknown", :unknown].each do |name|
      context "with #{name.inspect}" do
        it "returns the default theme" do
          expect(config.theme_for(name)).to equal(config.theme)
        end
      end
    end
  end

  describe "#theme_resolver" do
    it "reads the iron_admin_theme cookie by default" do
      expect(config.theme_resolver.call(request_with(cookie: "midnight"))).to eq("midnight")
    end

    it "returns the block it is given" do
      resolver = proc { :midnight }

      expect(config.theme_resolver(&resolver)).to equal(resolver)
    end
  end

  describe "#resolve_theme" do
    subject(:resolved) { config.resolve_theme(request) }

    let!(:midnight) { config.register_theme(:midnight) }

    context "with the cookie of a registered theme" do
      let(:request) { request_with(cookie: "midnight") }

      it "returns that theme" do
        expect(resolved).to equal(midnight)
      end
    end

    context "without the cookie" do
      let(:request) { request_with }

      it "returns the default theme" do
        expect(resolved).to equal(config.theme)
      end
    end

    context "with the cookie of an unknown theme" do
      let(:request) { request_with(cookie: "unknown") }

      it "returns the default theme" do
        expect(resolved).to equal(config.theme)
      end
    end

    context "with a custom resolver" do
      let(:request) { request_with }

      before { config.theme_resolver { |_request| :midnight } }

      it "returns the theme it names" do
        expect(resolved).to equal(midnight)
      end
    end

    context "with a resolver that returns nil" do
      let(:request) { request_with(cookie: "midnight") }

      before { config.theme_resolver { |_request| nil } }

      it "returns the default theme" do
        expect(resolved).to equal(config.theme)
      end
    end

    context "with a resolver that raises" do
      let(:request) { request_with(cookie: "midnight") }

      before do
        config.theme_resolver { |_request| raise "session store down" }
        allow(Rails.logger).to receive(:warn)
      end

      it "returns the default theme" do
        expect(resolved).to equal(config.theme)
      end

      it "logs a warning" do
        resolved

        expect(Rails.logger).to have_received(:warn).with(/theme_resolver raised RuntimeError: session store down/)
      end
    end
  end
end
