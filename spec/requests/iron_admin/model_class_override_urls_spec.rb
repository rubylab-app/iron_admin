# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Resources with model_class_override", type: :request do
  def boot_auto_note_resource
    IronAdmin::Resources.send(:remove_const, :AutoNoteResource) if IronAdmin::Resources.const_defined?(:AutoNoteResource, false)
    load Rails.root.join("app/iron_admin/resources/auto_note_resource.rb")
    IronAdmin::ResourceRegistry.finalize!
  end

  describe "AutoNoteResource" do
    # The dummy app overrides the engine layout, which is where the sidebar renders.
    around do |example|
      original_view_paths = IronAdmin::ApplicationController.view_paths
      IronAdmin::ApplicationController.prepend_view_path(IronAdmin::Engine.root.join("app/views"))
      example.run
    ensure
      IronAdmin::ApplicationController.view_paths = original_view_paths
    end

    before { boot_auto_note_resource }

    it "is reachable at the path derived from its class name" do
      get iron_admin.resources_path("auto_notes"), as: :html

      expect(response).to have_http_status(:ok)
    end

    it "points New at /admin/auto_notes" do
      get iron_admin.resources_path("auto_notes"), as: :html

      hrefs = response.parsed_body.css("a").pluck("href")
      expect(hrefs).to include(iron_admin.new_resource_path("auto_notes"))
    end

    it "points the row link at /admin/auto_notes" do
      note = Note.create!(title: "Hello", body: "World")
      get iron_admin.resources_path("auto_notes"), as: :html

      hrefs = response.parsed_body.css("a").pluck("href")
      expect(hrefs).to include(iron_admin.resource_path("auto_notes", note))
    end

    it "points Edit at /admin/auto_notes" do
      note = Note.create!(title: "Hello", body: "World")
      get iron_admin.resource_path("auto_notes", note), as: :html

      hrefs = response.parsed_body.css("a").pluck("href")
      expect(hrefs).to include(iron_admin.edit_resource_path("auto_notes", note))
    end

    it "points its sidebar link at that path" do
      get iron_admin.resources_path("auto_notes"), as: :html

      hrefs = response.parsed_body.css("#cp-sidebar-panel a").pluck("href")
      expect(hrefs).to include(iron_admin.resources_path("auto_notes"))
    end

    it "redirects a create to that resource" do
      post iron_admin.resources_path("auto_notes"),
           params: { record: { title: "Hello", body: "World" } },
           as: :html

      expect(response).to redirect_to(%r{/auto_notes/\d+\z})
    end

    it "leaves NoteResource at notes" do
      get iron_admin.resources_path("notes"), as: :html

      expect(response).to have_http_status(:ok)
      expect(IronAdmin::ResourceRegistry.find("notes")).to eq(IronAdmin::Resources::NoteResource)
      expect(IronAdmin::ResourceRegistry.find("auto_notes")).to eq(IronAdmin::Resources::AutoNoteResource)
    end
  end

  context "when two resources compute the same name" do
    after { remove_colliding_resources }

    def remove_colliding_resources
      %i[FirstCollidingNoteResource SecondCollidingNoteResource].each do |const_name|
        next unless IronAdmin::Resources.const_defined?(const_name, false)

        IronAdmin::Resources.send(:remove_const, const_name)
      end
    end

    def define_colliding_resources
      %i[FirstCollidingNoteResource SecondCollidingNoteResource].each do |const_name|
        next unless IronAdmin::Resources.const_defined?(const_name, false)

        IronAdmin::Resources.send(:remove_const, const_name)
      end

      IronAdmin::Resources.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        class FirstCollidingNoteResource < IronAdmin::Resource
          self.model_class_override = ::Note

          def self.resource_name
            "colliding_notes"
          end
        end

        class SecondCollidingNoteResource < IronAdmin::Resource
          self.model_class_override = ::Note

          def self.resource_name
            "colliding_notes"
          end
        end
      RUBY
    end

    it "keeps the first resource and logs both classes" do
      allow(Rails.logger).to receive(:error)
      define_colliding_resources
      IronAdmin::ResourceRegistry.finalize!

      registry = IronAdmin::ResourceRegistry
      expect(registry.find("colliding_notes")).to eq(IronAdmin::Resources::FirstCollidingNoteResource)
      expect(registry.all).not_to include(IronAdmin::Resources::SecondCollidingNoteResource)
      expect(Rails.logger).to have_received(:error).with(
        /SecondCollidingNoteResource.*colliding_notes.*FirstCollidingNoteResource.*def self\.resource_name/m
      )
    end
  end

  context "when a resource overrides self.model" do
    before do
      IronAdmin::ResourceRegistry.reset!
      define_expired_license_resource
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
      IronAdmin::ResourceRegistry.finalize!
    end

    after { remove_expired_license_resource }

    def define_expired_license_resource
      remove_expired_license_resource
      IronAdmin::Resources.module_eval(<<~RUBY, __FILE__, __LINE__ + 1)
        class ExpiredLicenseResource < IronAdmin::Resource
          def self.model
            ::License
          end
        end
      RUBY
    end

    def remove_expired_license_resource
      return unless IronAdmin::Resources.const_defined?(:ExpiredLicenseResource, false)

      IronAdmin::Resources.send(:remove_const, :ExpiredLicenseResource)
    end

    it "derives its name from the class path" do
      expect(IronAdmin::Resources::ExpiredLicenseResource.resource_name).to eq("expired_licenses")
    end

    it "keeps the canonical resource registered at licenses" do
      expect(IronAdmin::ResourceRegistry.find("licenses")).to eq(IronAdmin::Resources::LicenseResource)
    end

    it "registers the overriding resource beside it" do
      expect(IronAdmin::ResourceRegistry.find("expired_licenses")).to eq(IronAdmin::Resources::ExpiredLicenseResource)
    end

    it "serves the canonical resource at its url" do
      get iron_admin.resources_path("licenses"), as: :html

      labels = response.parsed_body.css("#bulk-actions-form button").map { |button| button.text.squish }
      expect(labels).to eq(["Export"])
    end
  end
end
