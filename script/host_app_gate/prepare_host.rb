#!/usr/bin/env ruby
# Customizes the generated host: the path gem, the admin flag, Product, seeds, and a root page.
# Usage: prepare_host.rb --app APP --package PATH --step gem|app

require "fileutils"
require "optparse"

options = {}
OptionParser.new do |parser|
  parser.on("--app APP") { |value| options[:app] = value }
  parser.on("--package PATH") { |value| options[:package] = value }
  parser.on("--step STEP") { |value| options[:step] = value }
  parser.on("--rails-version VERSION") { |value| options[:rails_version] = value }
end.parse!

# Applies one preparation step to a generated Rails host.
class HostAppGatePrepare
  def initialize(app, package, rails_version)
    @app = app
    @package = package
    @rails_version = rails_version
  end

  def apply(step)
    case step
    when "gem" then add_gem
    when "app" then prepare_app
    else raise "unknown step #{step}"
    end
  end

  private

  def add_gem
    pin_rails
    path = File.join(@app, "Gemfile")
    text = File.read(path)
    return if text.include?('gem "iron_admin"')

    File.write(path, "#{text.rstrip}\n\ngem \"iron_admin\", path: #{@package.dump}\n")
  end

  def pin_rails
    raise "rails version missing" unless @rails_version.is_a?(String) && !@rails_version.empty?

    path = File.join(@app, "Gemfile")
    text = File.read(path)
    pinned = %(gem "rails", "#{@rails_version}")
    return if text.match?(/^#{Regexp.escape(pinned)}$/)

    updated = text.sub(/^gem ["']rails["'],.*$/, pinned)
    raise "could not pin rails in the host Gemfile" if updated == text

    File.write(path, updated)
  end

  def prepare_app
    tighten_admin_column
    copy_templates
    set_root
  end

  def tighten_admin_column
    path = Dir[File.join(@app, "db/migrate/*_add_admin_to_users.rb")].first
    raise "admin migration missing" unless path

    text = File.read(path)
    needle = "add_column :users, :admin, :boolean"
    updated = text.sub(needle, "#{needle}, default: false, null: false")
    raise "could not set the admin column default in #{path}" if updated == text

    File.write(path, updated)
  end

  def copy_templates
    templates.each do |source, dest|
      target = File.join(@app, dest)
      FileUtils.mkdir_p(File.dirname(target))
      FileUtils.cp(File.join(__dir__, "app_files", source), target)
    end
  end

  def templates
    {
      "product.rb" => "app/models/product.rb",
      "seeds.rb" => "db/seeds.rb",
      "home_controller.rb" => "app/controllers/home_controller.rb",
      "home_index.html.erb" => "app/views/home/index.html.erb",
    }
  end

  def set_root
    path = File.join(@app, "config/routes.rb")
    text = File.read(path)
    return if text.match?(/^ *root "home#index"/)

    updated = text.sub(/^ *# root "posts#index"/, '  root "home#index"')
    updated = insert_root(updated) unless updated.match?(/^ *root "home#index"/)
    File.write(path, updated)
  end

  def insert_root(text)
    needle = "Rails.application.routes.draw do\n"
    raise "routes draw block missing" unless text.include?(needle)

    text.sub(needle, "#{needle}  root \"home#index\"\n")
  end
end

app = File.expand_path(options.fetch(:app))
package = File.realpath(options.fetch(:package))
HostAppGatePrepare.new(app, package, options[:rails_version]).apply(options.fetch(:step))
