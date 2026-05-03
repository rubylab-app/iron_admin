# frozen_string_literal: true

require "rails_helper"
require "rails/generators"
require "generators/iron_admin/install/install_generator"

RSpec.describe IronAdmin::Generators::InstallGenerator, type: :generator do
  let(:destination) { File.expand_path("../../tmp", __dir__) }

  before do
    FileUtils.rm_rf(destination)
    FileUtils.mkdir_p(destination)
    FileUtils.mkdir_p(File.join(destination, "config"))
    # Create a minimal routes file for the generator to modify
    File.write(File.join(destination, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
    # Create a minimal Tailwind application stylesheet
    FileUtils.mkdir_p(File.join(destination, "app/assets/tailwind"))
    File.write(File.join(destination, "app/assets/tailwind/application.css"), "@import \"tailwindcss\";\n")
  end

  after do
    FileUtils.rm_rf(destination)
  end

  def run_generator(args = [])
    described_class.start(args, destination_root: destination)
  end

  describe "running the install generator" do
    before { run_generator }

    it "creates the app/iron_admin/resources directory" do
      expect(Dir.exist?(File.join(destination, "app/iron_admin/resources"))).to be true
    end

    it "creates the app/iron_admin/dashboards directory" do
      expect(Dir.exist?(File.join(destination, "app/iron_admin/dashboards"))).to be true
    end

    it "creates the initializer" do
      initializer_path = File.join(destination, "config/initializers/iron_admin.rb")
      expect(File.exist?(initializer_path)).to be true
    end

    it "creates initializer with configuration block" do
      content = File.read(File.join(destination, "config/initializers/iron_admin.rb"))
      expect(content).to include("IronAdmin.configure do |config|")
      expect(content).to include("config.title")
    end

    it "creates the default dashboard" do
      dashboard_path = File.join(destination, "app/iron_admin/dashboards/admin_dashboard.rb")
      expect(File.exist?(dashboard_path)).to be true
    end

    it "creates dashboard with correct class" do
      content = File.read(File.join(destination, "app/iron_admin/dashboards/admin_dashboard.rb"))
      expect(content).to include("class AdminDashboard < IronAdmin::Dashboard")
      expect(content).to include("module IronAdmin")
      expect(content).to include("module Dashboards")
    end

    it "adds route to routes.rb" do
      content = File.read(File.join(destination, "config/routes.rb"))
      expect(content).to include('mount IronAdmin::Engine => "/admin"')
    end

    it "adds the Tailwind CSS import to application.css" do
      content = File.read(File.join(destination, "app/assets/tailwind/application.css"))
      expect(content).to include('@import "../builds/tailwind/iron_admin";')
    end

    it "preserves existing content in application.css" do
      content = File.read(File.join(destination, "app/assets/tailwind/application.css"))
      expect(content).to include('@import "tailwindcss";')
    end
  end

  describe "tailwind import idempotency" do
    it "does not duplicate the import when run twice" do
      run_generator
      run_generator
      content = File.read(File.join(destination, "app/assets/tailwind/application.css"))
      expect(content.scan('@import "../builds/tailwind/iron_admin";').length).to eq(1)
    end
  end

  context "when application.css does not exist" do
    before do
      FileUtils.rm_f(File.join(destination, "app/assets/tailwind/application.css"))
    end

    it "does not crash" do
      expect { run_generator }.not_to raise_error
    end

    it "does not create the missing Tailwind file" do
      run_generator
      expect(File.exist?(File.join(destination, "app/assets/tailwind/application.css"))).to be false
    end

    it "prints a `skip` status line with the import the user needs to add manually" do
      expect { run_generator }
        .to output(%r{skip.*@import "../builds/tailwind/iron_admin"}m).to_stdout
    end
  end

  context "when only the legacy tailwindcss-rails 3 / cssbundling layout exists" do
    before do
      FileUtils.rm_rf(File.join(destination, "app/assets/tailwind"))
      FileUtils.mkdir_p(File.join(destination, "app/assets/stylesheets"))
      File.write(
        File.join(destination, "app/assets/stylesheets/application.tailwind.css"),
        "@tailwind base;\n@tailwind components;\n@tailwind utilities;\n"
      )
      run_generator
    end

    it "appends the import to the legacy stylesheet" do
      content = File.read(File.join(destination, "app/assets/stylesheets/application.tailwind.css"))
      expect(content).to include('@import "../builds/tailwind/iron_admin";')
    end
  end
end
