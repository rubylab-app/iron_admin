# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Concerns::EventEmittable do
  subject(:password_names) { host.password_names }

  let(:resource_class) do
    Class.new(IronAdmin::Resource) do
      self.model_class_override = Document

      def self.name
        "PasswordNamesResource"
      end

      def self.resource_name
        "password_names"
      end
    end
  end

  let(:host) do
    resource = resource_class

    Class.new do
      include IronAdmin::Concerns::EventEmittable

      def initialize(resource_class)
        @resource_class = resource_class
      end

      def password_names
        password_field_names
      end
    end.new(resource)
  end

  before do
    fields = [
      IronAdmin::Field.new(:password_hash, type: :password),
      IronAdmin::Field.new(:title, type: :text),
    ]
    allow(resource_class).to receive(:resolved_fields).and_return(fields)
  end

  it "returns the names of password fields" do
    expect(password_names).to eq(["password_hash"])
  end
end
