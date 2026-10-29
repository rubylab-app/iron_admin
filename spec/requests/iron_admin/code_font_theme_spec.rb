# frozen_string_literal: true

require "rails_helper"

# Code-like values (code, JSON, key/value, markdown and hex color inputs, code blocks, audit
# change details) take their font family from the theme's code_font.
RSpec.describe "Code font theme", type: :request do
  let(:document) { response.parsed_body }
  let(:mono) { "font-[family-name:JetBrains_Mono,monospace]" }

  def classes_at(selector)
    document.at_css(selector)[:class].split
  end

  before do
    IronAdmin.configuration.register_theme(:terminal) { |t| t.code_font = "font-[family-name:JetBrains_Mono,monospace]" }
    cookies["iron_admin_theme"] = "terminal"
  end

  describe "GET /:resource_name/new with code and key/value fields" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::WidgetResource)
      get iron_admin.new_resource_path("widgets"), as: :html
    end

    it "sets code fields in code_font" do
      expect(classes_at("textarea#record_source_code")).to include(mono)
    end

    it "sets key/value fields in code_font" do
      expect(classes_at("textarea[name='record[config_json]']")).to include(mono)
    end

    it "drops the template's font-mono" do
      expect(classes_at("textarea#record_source_code")).not_to include("font-mono")
    end
  end

  describe "GET /:resource_name/new with markdown fields" do
    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::PostResource)
      get iron_admin.new_resource_path("posts"), as: :html
    end

    it "sets markdown fields in code_font" do
      expect(classes_at("textarea#record_body_markdown")).to include(mono)
    end
  end

  describe "GET /:resource_name/:id with a code field" do
    let(:widget) { create(:widget, source_code: "puts 'hello'") }

    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::WidgetResource)
      get iron_admin.resource_path("widgets", widget), as: :html
    end

    it "sets the code block in code_font" do
      expect(classes_at("pre code")).to include(mono)
    end
  end

  describe "GET /audit" do
    before do
      IronAdmin.configuration.audit_enabled = false
      get iron_admin.audit_path, as: :html
    end

    it "sets the configuration hint of the disabled warning in code_font" do
      expect(classes_at("code")).to include(mono)
    end
  end

  describe "GET /audit with changes" do
    before do
      IronAdmin.configuration.audit_enabled = true
      IronAdmin::AuditLog.log(Struct.new(:user, :action, :resource, :record_id, :changes, :ip_address)
                                    .new(nil, :update, "UserResource", 1, { name: %w[Ann Bea] }, nil))
      get iron_admin.audit_path, as: :html
    end

    it "sets the change details in code_font" do
      expect(classes_at("details summary + div")).to include(mono)
    end
  end
end
