# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rich text theme", type: :request do
  let(:editor) { response.parsed_body.at_css("trix-editor") }
  let(:neutral) { IronAdmin::Configuration::Theme.new }

  before { IronAdmin::ResourceRegistry.register(IronAdmin::Resources::DocumentResource) }

  context "with the Neutral theme" do
    before { get iron_admin.new_resource_path("documents"), as: :html }

    it "styles the editor like Neutral's inputs" do
      expect(editor[:class].split).to include(*neutral.rich_text_editor.split)
    end

    it "marks the editor for the engine's stylesheet, which hands Trix's border and radius to the theme" do
      expect(editor[:class].split).to include("cp-rich-text", "trix-content")
    end

    it "sets the editor's text at the size of the other inputs" do
      expect(editor[:class].split).to include("text-sm")
    end

    it "styles the toolbar with Neutral's rich_text_toolbar classes" do
      expect(editor.parent[:class].split).to include(*neutral.rich_text_toolbar.split)
    end

    it "marks the box around the toolbar for the engine's stylesheet, which wraps the toolbar's buttons" do
      expect(editor.parent[:class].split).to include("cp-rich-text-field")
    end
  end

  describe "the editor's accessible name" do
    subject(:label) { response.parsed_body.at_css("label[for='#{editor[:id]}']") }

    before { get iron_admin.new_resource_path("documents"), as: :html }

    it "gives the field's label an id" do
      expect(label[:id]).to eq("record_content_label")
    end

    it "names the editor after that label, which a label's for cannot do for trix-editor" do
      expect(editor["aria-labelledby"]).to eq(label[:id])
    end
  end

  context "with a theme that leaves the editor and its toolbar to Trix" do
    before do
      IronAdmin.configuration.register_theme(:plain) do |t|
        t.rich_text_editor = ""
        t.rich_text_toolbar = ""
      end
      cookies["iron_admin_theme"] = "plain"
      get iron_admin.new_resource_path("documents"), as: :html
    end

    it "leaves the editor to Trix's stylesheet, at the size of the other inputs" do
      expect(editor[:class].split).to eq(%w[trix-content text-sm])
    end

    it "gives the box around the toolbar and the editor only the engine's mark" do
      expect(editor.parent[:class].split).to eq(["cp-rich-text-field"])
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
      expect(editor.parent[:class].split).to eq(["cp-rich-text-field", "[&_.trix-button-group]:border-zinc-700!"])
    end
  end
end
