# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Import::Parser::Csv do
  it "parses CSV uploads into hashes keyed by the source headers" do
    csv = StringIO.new("Name,Email,Active\nJane,jane@example.com,false\n")

    rows = described_class.new(csv).parse

    expect(rows).to eq([{ "Name" => "Jane", "Email" => "jane@example.com", "Active" => "false" }])
  end

  it "ignores completely blank rows" do
    csv = StringIO.new("Name,Email\nJane,jane@example.com\n,\n")

    rows = described_class.new(csv).parse

    expect(rows).to eq([{ "Name" => "Jane", "Email" => "jane@example.com" }])
  end
end
