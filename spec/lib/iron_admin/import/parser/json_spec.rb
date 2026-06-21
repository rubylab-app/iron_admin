# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Import::Parser::Json do
  it "parses JSON array uploads into hashes" do
    json = StringIO.new(%([{"Name":"Jane","Email":"jane@example.com"}]))

    rows = described_class.new(json).parse

    expect(rows).to eq([{ "Name" => "Jane", "Email" => "jane@example.com" }])
  end

  it "parses JSON uploads that wrap records in a records key" do
    json = StringIO.new(%({"records":[{"Name":"Jane","Email":"jane@example.com"}]}))

    rows = described_class.new(json).parse

    expect(rows).to eq([{ "Name" => "Jane", "Email" => "jane@example.com" }])
  end
end
