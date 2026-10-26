require_relative "lib/iron_admin/version"

Gem::Specification.new do |spec|
  spec.name        = "iron_admin"
  spec.version     = IronAdmin::VERSION
  spec.authors     = ["RubyLab"]
  spec.summary     = "Convention-over-configuration admin panel engine for Rails"
  spec.description = "IronAdmin is a convention-over-configuration admin panel engine for Ruby on Rails " \
                     "that automatically generates CRUD interfaces from your models with built-in support " \
                     "for search, filters, scopes, custom actions, theming, and policy-based authorization."
  spec.homepage    = "https://github.com/rubylab-app/iron_admin"
  spec.license     = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/rubylab-app/iron_admin/tree/v#{spec.version}"
  spec.metadata["changelog_uri"] = "https://github.com/rubylab-app/iron_admin/blob/v#{spec.version}/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubylab-app.github.io/iron_admin/"
  spec.metadata["bug_tracker_uri"] = "https://github.com/rubylab-app/iron_admin/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.required_ruby_version = ">= 3.3"

  # docs/site is the Jekyll source of documentation_uri (with its own Gemfile.lock);
  # the mobile audit is internal. Neither belongs in an installed gem.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir[
      "{app,config,lib,vendor}/**/*",
      "docs/**/*.md",
      "CHANGELOG.md",
      "MIT-LICENSE",
      "README.md",
      "UPGRADING.md"
    ].reject { |path| path.start_with?("docs/site/") || path == "docs/mobile-responsiveness-audit.md" }
  end

  spec.add_dependency "csv", ">= 3.2.8"
  spec.add_dependency "haml-rails", ">= 2.0"
  spec.add_dependency "heroicon", ">= 1.0"
  spec.add_dependency "importmap-rails", ">= 2.0"
  spec.add_dependency "ostruct", ">= 0.6"
  spec.add_dependency "pagy", ">= 43.7.1", "< 44"
  spec.add_dependency "rails", ">= 8.0.4"
  spec.add_dependency "stimulus-rails", ">= 1.3"
  spec.add_dependency "turbo-rails", ">= 2.0.6"
  spec.add_dependency "view_component", ">= 4.0", "< 5"

  spec.add_development_dependency "factory_bot_rails", "~> 6.4"
  spec.add_development_dependency "faraday", "~> 2.0"
  spec.add_development_dependency "redcarpet", "~> 3.6"
  spec.add_development_dependency "rspec-rails", "~> 8.0"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-rails", "~> 2.23"
  spec.add_development_dependency "rubocop-rake", "~> 0.6"
  spec.add_development_dependency "rubocop-rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "simplecov-console", "~> 0.9"
  spec.add_development_dependency "sqlite3", "~> 2.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "yard", "~> 0.9"
end
