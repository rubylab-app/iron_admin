# Proves the initializer the install generator wrote, before any fixture
# replaces it. The generated authenticate block returns false, so a fresh
# install denies every request with 403 until authentication is wired. The
# fixture's recipe replaces it, and the admin checks then expect access.
$stdout.sync = true

title = IronAdmin.configuration.title.to_s
expected = "#{Rails.application.class.module_parent_name} Admin"
raise "generated title is #{title.inspect}, expected #{expected.inspect}" unless title == expected

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host! "localhost"
session.accept = "text/html"
session.get("/admin")
response = session.response
raise "GET /admin status #{response.status}, expected 403" unless response.status == 403

puts "HOST_APP_GATE smoke ok #{title}"
