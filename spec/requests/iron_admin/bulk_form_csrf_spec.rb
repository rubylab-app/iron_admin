# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bulk form authenticity token", type: :request do
  let!(:license) { create(:license) }

  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    example.run
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  # Forgery protection is on for this example, and the POST sends only the
  # token rendered in the index bulk form. No X-CSRF-Token header.
  it "accepts that token on the bulk action route" do
    get iron_admin.resources_path("licenses"), as: :html
    token = response.parsed_body.at_css("#bulk-actions-form input[name='authenticity_token']")["value"]

    post iron_admin.resource_bulk_action_path("licenses", "export"),
         params: { authenticity_token: token, ids: [license.id] },
         as: :html

    expect(response).to redirect_to(iron_admin.resources_path("licenses"))
  end
end
