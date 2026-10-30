require "uri"

# One integration session against the host app. Forgery protection stays on
# unless a block turns it off. Nothing here sends an X-CSRF-Token header.
class HostAppGateBrowser
  def self.with_forgery(enabled:)
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = enabled
    yield
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  def self.with_per_form_tokens
    previous = ActionController::Base.per_form_csrf_tokens
    ActionController::Base.per_form_csrf_tokens = true
    yield
  ensure
    ActionController::Base.per_form_csrf_tokens = previous
  end

  def self.sign_in(email, params = nil)
    # The generated SessionsController allows 10 sign-ins per 3 minutes for
    # this IP. One run signs in once per role plus the tampered and revoked
    # cases, and the development cache is that rate-limit store. Clear it
    # before each sign-in so a longer run is not locked out. The session
    # itself lives in the database and the cookie, not in this cache.
    clear_sign_in_rate_limit
    browser = new
    payload = params || { email_address: email, password: HostAppGate::PASSWORD }
    response = browser.post("/session", payload)
    browser.assert_signed_in(response, email)
    browser
  end

  def self.clear_sign_in_rate_limit
    Rails.cache.clear if Rails.cache.respond_to?(:clear)
  end

  def initialize
    @session = ActionDispatch::Integration::Session.new(Rails.application)
    @session.host! "localhost"
    @session.accept = "text/html"
  end

  def get(path, params = nil, accept: nil)
    previous = @session.accept
    @session.accept = accept if accept
    request(:get, path, params)
  ensure
    @session.accept = previous if accept
  end

  def post(path, params = nil)
    request(:post, path, params)
  end

  def patch(path, params = nil)
    request(:patch, path, params)
  end

  def delete(path, params = nil)
    request(:delete, path, params)
  end

  def request(verb, path, params = nil)
    @session.public_send(verb, path, params: params)
    @session.response
  end

  def tamper_session_cookie
    current = @session.cookies["session_id"]
    raise HostAppGateFailure, "no session cookie to tamper" if current.blank?

    @session.cookies["session_id"] = "#{current}x"
  end

  def revoke_session(email)
    revoked = User.find_by!(email_address: email).sessions.destroy_all
    raise HostAppGateFailure, "no session row to revoke" if revoked.empty?
  end

  def assert_signed_in(response, email)
    return if response.redirect? && URI.parse(response.location).path != HostAppGate::SIGN_IN_PATH

    detail = response.redirect? ? URI.parse(response.location).path : "status #{response.status}"
    raise HostAppGateFailure, "sign-in for #{email} failed (#{detail})"
  end
end
