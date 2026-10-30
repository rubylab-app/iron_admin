IronAdmin.configure do |config|
  config.title = "Shop Admin"

  # Rails 8 authentication generator: the session id lives in the signed
  # session_id cookie. Visitors who are not signed in are sent to sign-in.
  # Any signed-in user passes on purpose, so the resource policy can be
  # checked for a member and for an admin. An admin-only panel should use
  # the recipe in docs/guides/authentication.md: that block returns false,
  # and false denies the request.
  config.authenticate do |controller|
    session_record = Session.find_by(id: controller.request.cookie_jar.signed[:session_id])
    controller.redirect_to "/session/new" unless session_record&.user
  end

  config.current_user do |controller|
    Session.find_by(id: controller.request.cookie_jar.signed[:session_id])&.user
  end
end
