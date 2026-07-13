require "spec_helper"
ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "factory_bot_rails"
require "view_component/test_helpers"

# Load schema before tests run.
ActiveRecord::Schema.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

# Refresh column caches on any model eagerly loaded by Rails BEFORE the
# schema reload happened — otherwise newly-added columns are invisible
# to those models. CI uses `config.eager_load = true`, which loads every
# model during `environment.rb` (one require above). Without this, e.g.
# `User.create!(preferences: ...)` raises UnknownAttributeError on CI
# but works locally where eager_load is off.
ActiveRecord::Base.descendants.each(&:reset_column_information) if defined?(ActiveRecord::Base)

# Load test resources (before support files, since test_resources.rb aliases depend on these)
require_relative "dummy/app/iron_admin/resources/user_resource"
require_relative "dummy/app/iron_admin/resources/license_resource"
require_relative "dummy/app/iron_admin/resources/post_resource"
require_relative "dummy/app/iron_admin/resources/document_resource"
require_relative "dummy/app/iron_admin/resources/profile_resource"
require_relative "dummy/app/iron_admin/resources/tag_resource"
require_relative "dummy/app/iron_admin/resources/note_resource"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include IronAdmin::Engine.routes.url_helpers, type: :request
  config.include ViewComponent::TestHelpers, type: :component
  config.include IronAdmin::Engine.routes.url_helpers, type: :component

  config.before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::AuditLog.clear!
    IronAdmin::FieldTypeRegistry.reset!
    IronAdmin::ToolRegistry.reset!
    IronAdmin::MenuRegistry.reset!
    IronAdmin::PluginRegistry.reset!
  end

  config.before(:each, type: :request) do
    # Re-register resources for request specs
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::NoteResource)
  end

  config.before(:each, type: :component) do
    # Re-register resources for component specs
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::NoteResource)

    # Set up route helpers for component tests
    vc_test_controller.view_context.class.define_method(:iron_admin) do
      IronAdmin::Engine.routes.url_helpers
    end
  end
end
