# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rich text theme", type: :request do
  let(:editor) { response.parsed_body.at_css("trix-editor") }

  before { IronAdmin::ResourceRegistry.register(IronAdmin::Resources::DocumentResource) }

  context "with the Neutral theme" do
    before { get iron_admin.new_resource_path("documents"), as: :html }

    it "leaves the editor to Trix's stylesheet" do
      expect(editor[:class].split).to eq(%w[trix-content])
    end

    it "gives the box around the toolbar and the editor no classes" do
      expect(editor.parent[:class].to_s.split).to be_empty
    end
  end

  context "with a theme that styles the editor and its toolbar" do
    before do
      IronAdmin.configuration.register_theme(:night) do |t|
        t.rich_text_editor = "border border-zinc-700 rounded-md bg-zinc-900 focus:border-violet-500"
        t.rich_text_toolbar = "[&_.trix-button-group]:border-zinc-700!"
      end
      cookies["iron_admin_theme"] = "night"
      get iron_admin.new_resource_path("documents"), as: :html
    end

    it "gives the editor that theme's rich_text_editor classes" do
      expect(editor[:class].split).to include("border-zinc-700", "rounded-md", "bg-zinc-900", "focus:border-violet-500")
    end

    it "marks the editor for the engine's stylesheet, which hands Trix's border and radius to the theme" do
      expect(editor[:class].split).to include("cp-rich-text", "trix-content")
    end

    it "gives the box around the toolbar and the editor that theme's rich_text_toolbar classes" do
      expect(editor.parent[:class].split).to eq(["[&_.trix-button-group]:border-zinc-700!"])
    end
  end
end
