# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Live::PollCache do
  it "stores and drains updates by stream name" do
    cache = described_class.new

    cache.push("dashboard", "<turbo-stream>one</turbo-stream>")
    cache.push("dashboard", "<turbo-stream>two</turbo-stream>")

    expect(cache.fetch("dashboard")).to eq(["<turbo-stream>one</turbo-stream>", "<turbo-stream>two</turbo-stream>"])
    expect(cache.fetch("dashboard")).to eq([])
  end

  it "keeps streams isolated" do
    cache = described_class.new

    cache.push("dashboard", "dashboard-update")
    cache.push("users:index", "users-update")

    expect(cache.fetch("dashboard")).to eq(["dashboard-update"])
    expect(cache.fetch("users:index")).to eq(["users-update"])
  end
end
