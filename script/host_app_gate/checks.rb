# Host-app gate checks. Run from the generated host with `bin/rails runner`:
#
#   IRON_ADMIN_PACKAGE_ROOT=... HOST_APP_GATE_RESULT=... bin/rails runner checks.rb
#
# A check that raises is a failure. The process exits non-zero when any fail.
$stdout.sync = true
require "nokogiri"

require_relative "gate"
require_relative "report"
require_relative "assertions"
require_relative "data"
require_relative "browser"
require_relative "boot_checks"
require_relative "asset_checks"
require_relative "access_checks"
require_relative "admin_checks"
require_relative "csrf_checks"
require_relative "recipe_checks"

if defined?(ActiveRecord::QueryLogs) && ActiveRecord.respond_to?(:query_transformers)
  ActiveRecord.query_transformers.delete(ActiveRecord::QueryLogs)
end

# Group order is load-bearing for data and configuration. Access and admin
# checks change records under the fixture authentication. CSRF runs after
# those writes, with forgery protection on. The recipe group replaces the
# authentication blocks, restores them when it finishes, and stays last so a
# denial there cannot mask an earlier data failure.
report = HostAppGateReport.new
HostAppGateBootChecks.new(report).run
HostAppGateAssetChecks.new(report).run
HostAppGateAccessChecks.new(report).run
HostAppGateAdminChecks.new(report).run
HostAppGateCsrfChecks.new(report).run
HostAppGateRecipeChecks.new(report).run
report.finish
