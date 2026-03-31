# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Tool do
  before { IronAdmin::ToolRegistry.reset! }

  describe ".tool_name" do
    it "derives name from class" do
      tool_class = Class.new(described_class) do
        def self.name = "ImportTool"
      end

      expect(tool_class.tool_name).to eq("import")
    end
  end

  describe ".menu" do
    it "stores menu options" do
      tool_class = Class.new(described_class) do
        def self.name = "ImportTool"
      end
      tool_class.menu icon: "arrow-up-tray", label: "Import Data", priority: 10

      expect(tool_class.menu_options[:icon]).to eq("arrow-up-tray")
      expect(tool_class.menu_options[:label]).to eq("Import Data")
      expect(tool_class.menu_options[:priority]).to eq(10)
    end
  end

  describe ".label" do
    context "when menu label is set" do
      it "returns the custom label" do
        tool_class = Class.new(described_class) do
          def self.name = "ImportTool"
        end
        tool_class.menu label: "Custom Label"

        expect(tool_class.label).to eq("Custom Label")
      end
    end

    context "when no menu label" do
      it "returns humanized tool name" do
        tool_class = Class.new(described_class) do
          def self.name = "ImportTool"
        end

        expect(tool_class.label).to eq("Import")
      end
    end
  end

  describe ".tool_action" do
    let(:tool_class) do
      Class.new(described_class) do
        self.menu_options = { label: "Test Tool" }

        tool_action :run_report,
                    label: "Generate Report",
                    icon: "document",
                    confirm: true,
                    form_fields: [{ name: :format, type: :select, options: %w[csv pdf] }],
                    condition: ->(user) { user&.admin? }

        tool_action :clear_cache,
                    label: "Clear Cache",
                    icon: "trash"
      end
    end

    it "registers actions in defined_tool_actions" do
      expect(tool_class.defined_tool_actions.size).to eq(2)
    end

    it "stores ToolAction objects" do
      action = tool_class.defined_tool_actions.find { |a| a.name == :run_report }

      expect(action).to be_a(IronAdmin::ToolAction)
      expect(action.label).to eq("Generate Report")
      expect(action.icon).to eq("document")
      expect(action.confirm).to be(true)
    end

    it "stores form fields on the action" do
      action = tool_class.defined_tool_actions.find { |a| a.name == :run_report }

      expect(action.form_fields.size).to eq(1)
      expect(action.form_fields.first.name).to eq(:format)
    end

    it "stores condition on the action" do
      action = tool_class.defined_tool_actions.find { |a| a.name == :run_report }

      expect(action.condition).to be_a(Proc)
    end
  end

  describe ".find_tool_action" do
    let(:tool_class) do
      Class.new(described_class) do
        tool_action :run_report, label: "Report"

        def run_report; end

        def undeclared_method; end
      end
    end

    context "with a declared action" do
      it "returns the ToolAction" do
        action = tool_class.find_tool_action(:run_report)
        expect(action).to be_a(IronAdmin::ToolAction)
        expect(action.name).to eq(:run_report)
      end
    end

    context "with an undeclared method" do
      it "returns nil" do
        expect(tool_class.find_tool_action(:undeclared_method)).to be_nil
      end
    end

    context "with a nonexistent method" do
      it "returns nil" do
        expect(tool_class.find_tool_action(:nonexistent)).to be_nil
      end
    end
  end

  describe "#context" do
    let(:tool_class) { Class.new(described_class) }

    it "is nil by default" do
      expect(tool_class.new.context).to be_nil
    end

    it "can be set" do
      tool = tool_class.new
      ctx = IronAdmin::ToolContext.new(params: {}, current_user: nil, flash: nil)
      tool.context = ctx
      expect(tool.context).to eq(ctx)
    end
  end

  describe "inheritance isolation" do
    let(:parent_class) do
      Class.new(described_class) do
        tool_action :parent_action, label: "Parent"
      end
    end

    let(:child_class) do
      Class.new(parent_class) do
        tool_action :child_action, label: "Child"
      end
    end

    it "child inherits parent actions" do
      names = child_class.defined_tool_actions.map(&:name)
      expect(names).to include(:parent_action, :child_action)
    end

    it "parent is not modified by child" do
      child_class # force evaluation
      names = parent_class.defined_tool_actions.map(&:name)
      expect(names).not_to include(:child_action)
    end
  end
end
