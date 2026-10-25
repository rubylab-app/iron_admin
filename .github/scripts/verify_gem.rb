# Sanity-checks a built gem (CI "Gem package" job, and release.yml before `gem push`).
# Run from the repository root:
#
#   ruby .github/scripts/verify_gem.rb iron_admin-0.7.0.gem [EXPECTED_VERSION]
require "open3"
require "rubygems/package"

$stdout.sync = true

# Files the engine cannot boot or render without.
REQUIRED_FILES = %w[
  MIT-LICENSE
  README.md
  app/assets/config/iron_admin_manifest.js
  app/javascript/iron_admin/index.js
  app/views/layouts/iron_admin/application.html.haml
  config/importmap.rb
  config/routes.rb
  lib/iron_admin.rb
  lib/iron_admin/engine.rb
  lib/iron_admin/version.rb
  vendor/assets/javascripts/chart.min.js
].freeze

# Repository-only paths that must never ship. vendor/bundle is what leaked into the
# published 0.6.0: setup-ruby's bundler-cache installs gems there and the gemspec's
# vendor/**/* glob swept them in.
FORBIDDEN_DIRS = %w[.bundle .github coverage docs/site gemfiles log pkg spec test tmp vendor/bundle].freeze
FORBIDDEN_PATH = %r{\A(?:#{FORBIDDEN_DIRS.map { |dir| Regexp.escape(dir) }.join("|")})/|(?:\A|/)Gemfile(?:\.lock)?\z|\.gem\z}

# A clean 0.7.0 build is a few hundred KiB; the published 0.6.0 was 43.9 MB.
MAX_SIZE_BYTES = 1_000_000
MAX_LISTED = 20

# Lists at most MAX_LISTED paths so a leak like 0.6.0's stays readable.
def add_path_errors(errors, message, paths)
  paths.first(MAX_LISTED).each { |path| errors << "#{message}: #{path}" }
  errors << "...and #{paths.size - MAX_LISTED} more" if paths.size > MAX_LISTED
end

# Files tracked by git, relative to the repository root, or nil outside a checkout.
def tracked_files
  root, status = Open3.capture2("git", "rev-parse", "--show-toplevel", err: File::NULL)
  return unless status.success?

  list, status = Open3.capture2("git", "-C", root.chomp, "ls-files", "-z", err: File::NULL)
  list.split("\0") if status.success?
rescue SystemCallError
  nil
end

gem_path, expected_version = ARGV
abort "usage: ruby #{$PROGRAM_NAME} GEM_FILE [EXPECTED_VERSION]" unless gem_path && File.file?(gem_path)

package = Gem::Package.new(gem_path)
spec = package.spec
files = package.contents
size = File.size(gem_path)

errors = []
if expected_version && spec.version.to_s != expected_version
  errors << "gem version #{spec.version} does not match expected version #{expected_version}"
end
(REQUIRED_FILES - files).each { |path| errors << "missing required file: #{path}" }

leaked = files.grep(FORBIDDEN_PATH)
add_path_errors(errors, "repository-only file packaged", leaked)

# spec.files is a Dir glob, so any stray file in the checkout can be packaged.
tracked = tracked_files
if tracked
  add_path_errors(errors, "untracked file packaged", files - tracked - leaked)
else
  puts "Not in a git checkout; skipping the untracked-file check"
end

errors << "gem is #{size} bytes, over the #{MAX_SIZE_BYTES}-byte limit" if size > MAX_SIZE_BYTES

puts "#{spec.full_name}: #{files.size} files, #{size / 1024} KiB"
abort(errors.map { |error| "::error::#{error}" }.join("\n")) unless errors.empty?
puts "Gem contents OK"
