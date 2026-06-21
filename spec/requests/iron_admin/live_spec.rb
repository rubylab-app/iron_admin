# frozen_string_literal: true

require "rails_helper"

RSpec.describe "IronAdmin::Live", type: :request do
  it "returns not found while live updates are disabled" do
    get iron_admin.live_path("dashboard"), headers: turbo_stream_headers

    expect(response).to have_http_status(:not_found)
  end

  it "returns and drains pending Turbo Stream updates when polling is enabled" do
    IronAdmin.configuration.live_updates = :polling
    IronAdmin::Live.poll_cache.push("dashboard", %(<turbo-stream action="replace" target="metric_total_users"><template>42</template></turbo-stream>))

    get iron_admin.live_path("dashboard"), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(response.body).to include(%(target="metric_total_users"))

    get iron_admin.live_path("dashboard"), headers: turbo_stream_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("")
  end

  def turbo_stream_headers
    { "ACCEPT" => "text/vnd.turbo-stream.html" }
  end
end
