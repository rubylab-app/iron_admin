IronAdmin.configure do |config|
  config.title = "Shop Admin"

  # Negative control: every visitor is signed in, including anonymous ones.
  config.authenticate do |_controller|
    true
  end

  config.current_user do |controller|
    Session.find_by(id: controller.request.cookie_jar.signed[:session_id])&.user
  end
end
