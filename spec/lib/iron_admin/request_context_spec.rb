# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::RequestContext do
  let(:theme) { IronAdmin::Configuration::Theme.new(name: :midnight) }

  describe ".theme" do
    it "is nil until a request sets it" do
      expect(described_class.theme).to be_nil
    end

    it "returns the theme set for the request" do
      described_class.theme = theme

      expect(described_class.theme).to equal(theme)
    end
  end

  describe ".reset" do
    it "clears the theme" do
      described_class.theme = theme
      described_class.reset

      expect(described_class.theme).to be_nil
    end
  end

  it "is a CurrentAttributes class, which Rails resets around every request" do
    expect(described_class.superclass).to eq(ActiveSupport::CurrentAttributes)
  end

  # Resource files are written inside module IronAdmin; module Resources, so a
  # file loaded there has that lexical scope. module_eval does not.
  context "when a resource file refers to Current" do
    let(:probe_dir) { Dir.mktmpdir }

    after { remove_lexical_probe }

    def remove_lexical_probe
      if IronAdmin::Resources.const_defined?(:LexicalCurrentProbeResource, false)
        IronAdmin::Resources.send(:remove_const, :LexicalCurrentProbeResource)
      end
      FileUtils.remove_entry(probe_dir)
    end

    def define_lexical_probe
      probe_path = File.join(probe_dir, "lexical_current_probe.rb")
      File.write(probe_path, <<~RUBY)
        module IronAdmin
          module Resources
            class LexicalCurrentProbeResource < IronAdmin::Resource
              HOST_USER = -> { Current.user }
            end
          end
        end
      RUBY
      load probe_path
      IronAdmin::Resources::LexicalCurrentProbeResource
    end

    it "resolves Current to the host's Current" do
      host_current = Class.new do
        def self.user
          "host-user"
        end
      end
      stub_const("Current", host_current)

      expect(define_lexical_probe::HOST_USER.call).to eq("host-user")
    end
  end
end
