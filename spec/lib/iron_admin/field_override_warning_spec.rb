# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::FieldOverrideWarning do
  before { described_class.reset! }

  let(:logger) { instance_double(Logger, warn: nil) }

  def build_license_resource(class_name, &block)
    resource = Class.new(IronAdmin::Resource)
    resource.class_eval do
      define_singleton_method(:name) { class_name }
      define_singleton_method(:resource_name) { class_name }
      self.model_class_override = License
    end
    resource.class_eval(&block)
    IronAdmin::ResourceRegistry.register(resource)
    resource
  end

  def environment(name)
    ActiveSupport::EnvironmentInquirer.new(name)
  end

  def warn_about(resource, env:)
    described_class.call(resources: [resource], env: environment(env), logger: logger)
  end

  describe "Resource.unresolved_field_overrides" do
    it "returns overrides that are neither a field nor a belongs_to foreign key" do
      resource = build_license_resource("UnresolvedLicenseResource") do
        field :user_id, readonly: true
        field :nonexistent_column, label: "X"
      end

      expect(resource.unresolved_field_overrides).to eq([:nonexistent_column])
    end
  end

  it "logs once naming the resource and the unknown field" do
    resource = build_license_resource("UnresolvedLicenseResource") do
      field :user_id, readonly: true
      field :nonexistent_column, label: "X"
    end

    logged = warn_about(resource, env: "development")

    expect(logged).to be(true)
    expect(logger).to have_received(:warn).once.with(
      "[IronAdmin] UnresolvedLicenseResource: field :nonexistent_column matches no field, " \
      "so its options are ignored."
    )
  end

  it "adds a foreign key hint when an unresolved name ends in _id" do
    resource = build_license_resource("OrganisationHintResource") do
      field :organisation_id, readonly: true
    end

    warn_about(resource, env: "development")

    expect(logger).to have_received(:warn).with(
      "[IronAdmin] OrganisationHintResource: field :organisation_id matches no field, " \
      "so its options are ignored. Foreign keys of belongs_to associations are " \
      "configured under the association name."
    )
  end

  it "stays quiet in production" do
    resource = build_license_resource("ProductionLicenseResource") do
      field :nonexistent_column, label: "X"
    end

    logged = warn_about(resource, env: "production")

    expect(logged).to be(false)
    expect(logger).not_to have_received(:warn)
  end

  it "stays quiet when every override matches a field or foreign key" do
    resource = build_license_resource("ResolvedLicenseResource") do
      field :user_id, readonly: true
    end

    logged = warn_about(resource, env: "development")

    expect(logged).to be(false)
    expect(logger).not_to have_received(:warn)
  end

  it "does not repeat a warning for the same set" do
    resource = build_license_resource("RepeatLicenseResource") do
      field :nonexistent_column, label: "X"
    end

    warn_about(resource, env: "development")
    logged_again = warn_about(resource, env: "development")

    expect(logged_again).to be(false)
    expect(logger).to have_received(:warn).once
  end
end
