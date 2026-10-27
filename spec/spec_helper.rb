require "simplecov"
require "simplecov-console"

SimpleCov.start "rails" do
  skip "/spec/"
  skip "/lib/generators/"
  skip "/lib/iron_admin/version.rb"
  skip "/lib/iron_admin/engine.rb"

  group "Lib", "lib/iron_admin"
  group "Controllers", "app/controllers"
  group "Components", "app/components"
  group "Helpers", "app/helpers"

  coverage :line do
    minimum 90
    minimum 80, per: :file
  end

  formatter SimpleCov::Formatter::MultiFormatter.new([
                                                       SimpleCov::Formatter::HTMLFormatter,
                                                       SimpleCov::Formatter::Console,
                                                     ])
end

require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end
