# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::AuthenticationWarning do
  let(:logger) { instance_double(Logger, warn: nil) }
  let(:production) { ActiveSupport::EnvironmentInquirer.new("production") }
  let(:development) { ActiveSupport::EnvironmentInquirer.new("development") }

  it "warns in production when no authenticate block is configured" do
    expect(described_class.call(env: production, logger: logger)).to be(true)
    expect(logger).to have_received(:warn).with(a_string_including("config.authenticate is not set"))
  end

  it "says that a route constraint still protects the mount" do
    described_class.call(env: production, logger: logger)

    expect(logger).to have_received(:warn).with(a_string_including("route constraint"))
  end

  it "stays quiet in production when an authenticate block is configured" do
    IronAdmin.configuration.authenticate { |_controller| false }

    expect(described_class.call(env: production, logger: logger)).to be(false)
    expect(logger).not_to have_received(:warn)
  end

  it "stays quiet outside production" do
    expect(described_class.call(env: development, logger: logger)).to be(false)
    expect(logger).not_to have_received(:warn)
  end
end
