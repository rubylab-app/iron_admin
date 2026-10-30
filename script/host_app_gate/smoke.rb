# Proves the initializer the install generator wrote, before any fixture
# replaces it. The generated authenticate and current_user blocks are
# comments, so they return nil and the request is allowed.
$stdout.sync = true

title = IronAdmin.configuration.title.to_s
expected = "#{Rails.application.class.module_parent_name} Admin"
raise "generated title is #{title.inspect}, expected #{expected.inspect}" unless title == expected

session = ActionDispatch::Integration::Session.new(Rails.application)
session.host! "localhost"
session.accept = "text/html"
session.get("/admin")
response = session.response
raise "GET /admin status #{response.status}, expected 200" unless response.status == 200
raise "GET /admin did not render #{title.inspect}" unless response.body.include?(title)

puts "HOST_APP_GATE smoke ok #{title}"
