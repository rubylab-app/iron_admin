# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::PolicyCoverageWarning do
  let(:logger) { instance_double(Logger, warn: nil) }
  let(:development) { ActiveSupport::EnvironmentInquirer.new("development") }
  let(:production) { ActiveSupport::EnvironmentInquirer.new("production") }
  let(:open_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name = "OpenUserResource"
    end
  end
  let(:guarded_resource) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = User

      def self.name = "GuardedUserResource"

      policy { allow :read }
    end
  end

  before { described_class.reset! }

  it "lists the resources without a policy in development" do
    expect(described_class.call(resources: [open_resource, guarded_resource], env: development, logger: logger)).to be(true)
    expect(logger).to have_received(:warn).with(a_string_including("OpenUserResource").and(excluding("GuardedUserResource")))
  end

  it "names the setting that denies them" do
    described_class.call(resources: [open_resource], env: development, logger: logger)

    expect(logger).to have_received(:warn).with(a_string_including("config.default_policy = :deny"))
  end

  it "warns once for the same resources" do
    described_class.call(resources: [open_resource], env: development, logger: logger)

    expect(described_class.call(resources: [open_resource], env: development, logger: logger)).to be(false)
    expect(logger).to have_received(:warn).once
  end

  it "stays quiet when default_policy is :deny" do
    IronAdmin.configuration.default_policy = :deny

    expect(described_class.call(resources: [open_resource], env: development, logger: logger)).to be(false)
  end

  it "stays quiet outside development" do
    expect(described_class.call(resources: [open_resource], env: production, logger: logger)).to be(false)
  end

  it "stays quiet when every resource has a policy" do
    expect(described_class.call(resources: [guarded_resource], env: development, logger: logger)).to be(false)
  end

  def excluding(text)
    satisfy { |message| message.exclude?(text) }
  end
end
