# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe "Tool system enhancements", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ToolRegistry.reset!
  end

  describe "context injection" do
    let(:tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "ContextTestTool"

        menu label: "Context Test"

        tool_action :check_context

        def check_context(ctx)
          # Store context data for verification via class variable
          self.class.last_context = ctx
        end

        class_attribute :last_context
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    it "injects ToolContext into the action method" do
      post tool_action_path("context_test", "check_context"), as: :html

      expect(tool_class.last_context).to be_a(IronAdmin::ToolContext)
    end

    it "includes params in the context" do
      post tool_action_path("context_test", "check_context"), as: :html

      expect(tool_class.last_context.params).to be_present
    end
  end

  describe "tool_action authorization" do
    let(:tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "AuthTestTool"

        menu label: "Auth Test"

        tool_action :admin_only, condition: ->(user) { user&.role == "admin" }

        def admin_only(ctx)
          # authorized action
        end
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    context "when user is authorized" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "admin") }
        end
      end

      it "executes the action" do
        post tool_action_path("auth_test", "admin_only"), as: :html
        expect(response).to redirect_to(tool_path("auth_test"))
      end
    end

    context "when user is not authorized" do
      before do
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(role: "viewer") }
        end
      end

      it "returns 403 forbidden" do
        post tool_action_path("auth_test", "admin_only"), as: :html
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "tool action form rendering" do
    let(:tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "FormTestTool"

        menu label: "Form Test"

        tool_action :with_form,
                    label: "Action With Form",
                    form_fields: [
                      { name: :reason, type: :textarea, required: true },
                      { name: :priority, type: :select, options: %w[low medium high] },
                    ]

        tool_action :without_form, label: "Simple Action"

        def with_form(ctx)
          # noop
        end

        def without_form
          # noop
        end
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    context "with an action that has form_fields" do
      it "renders the form page" do
        get tool_action_form_path("form_test", "with_form"), as: :html

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Reason")
        expect(response.body).to include("Priority")
      end
    end

    context "with an action without form_fields" do
      it "returns 404" do
        get tool_action_form_path("form_test", "without_form"), as: :html
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a nonexistent action" do
      it "returns 404" do
        get tool_action_form_path("form_test", "nonexistent"), as: :html
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "backward compatibility with legacy bare-method tools" do
    let(:tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "LegacyTool"

        menu label: "Legacy"

        def legacy_action
          # bare method, no tool_action declaration
        end
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    it "executes undeclared methods via fallback" do
      post tool_action_path("legacy", "legacy_action"), as: :html
      expect(response).to redirect_to(tool_path("legacy"))
    end
  end

  describe "arity detection for context" do
    let(:tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "ArityTool"

        menu label: "Arity"
        class_attribute :called_with_context, default: false

        tool_action :no_args_action
        tool_action :with_args_action

        def no_args_action
          # 0-arg: should NOT receive context
          self.class.called_with_context = false
        end

        def with_args_action(ctx)
          # 1-arg: SHOULD receive context
          self.class.called_with_context = ctx.is_a?(IronAdmin::ToolContext)
        end
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    it "does not pass context to 0-arg methods" do
      post tool_action_path("arity", "no_args_action"), as: :html
      expect(response).to redirect_to(tool_path("arity"))
    end

    it "passes context to 1-arg methods" do
      post tool_action_path("arity", "with_args_action"), as: :html
      expect(tool_class.called_with_context).to be(true)
    end
  end

  describe "show page with declared actions" do
    let(:tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "ShowTestTool"

        menu label: "Show Test"

        tool_action :visible_action, label: "Visible", icon: "check"
        tool_action :hidden_action, label: "Hidden", condition: ->(_u) { false }

        def visible_action; end

        def hidden_action; end
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    it "displays authorized action buttons" do
      get tool_path("show_test"), as: :html

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Visible")
    end

    it "hides unauthorized action buttons" do
      get tool_path("show_test"), as: :html

      expect(response.body).not_to include("Hidden")
    end
  end

  describe "declared action without method implementation" do
    let(:tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "MissingMethodTool"

        menu label: "Missing Method"

        tool_action :unimplemented_action, label: "Ghost"
        # No def unimplemented_action — intentionally missing
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    it "returns 404 instead of 500" do
      post tool_action_path("missing_method", "unimplemented_action"), as: :html
      expect(response).to have_http_status(:not_found)
    end
  end
end
