# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Live::Broadcaster do
  it "stores replace actions as Turbo Stream markup in the poll cache" do
    cache = IronAdmin::Live::PollCache.new
    broadcaster = described_class.new(cache: cache)

    broadcaster.broadcast_replace("dashboard", target: "metric_total_users", html: "<div>42</div>")

    body = cache.fetch("dashboard").join
    expect(body).to include(%(action="replace"))
    expect(body).to include(%(target="metric_total_users"))
    expect(body).to include("<div>42</div>")
  end

  it "stores remove actions without a template" do
    cache = IronAdmin::Live::PollCache.new
    broadcaster = described_class.new(cache: cache)

    broadcaster.broadcast_remove("users:index", target: "iron_admin_users_row_1")

    body = cache.fetch("users:index").join
    expect(body).to include(%(action="remove"))
    expect(body).to include(%(target="iron_admin_users_row_1"))
    expect(body).not_to include("<template>")
  end
end
