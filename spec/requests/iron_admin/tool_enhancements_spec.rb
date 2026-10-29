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

      it "renders the textarea as a theme textarea" do
        get tool_action_form_path("form_test", "with_form"), as: :html

        expect(response.parsed_body.at_css("#tool_action_reason")[:class].split)
          .to eq(IronAdmin::Form::ControlClasses.textarea(IronAdmin.configuration.theme).split)
      end

      it "renders the select as a theme select" do
        get tool_action_form_path("form_test", "with_form"), as: :html

        expect(response.parsed_body.at_css("#tool_action_priority")[:class].split)
          .to eq(IronAdmin::Form::ControlClasses.select(IronAdmin.configuration.theme).split)
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

        class_attribute :called, default: []

        def legacy_action
          self.class.called = called + [:legacy_action]
        end

        def other_action
          self.class.called = called + [:other_action]
        end

        def hidden_helper
          self.class.called = called + [:hidden_helper]
        end
        protected :hidden_helper
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    context "when the fallback runs" do
      before { allow(IronAdmin.deprecator).to receive(:warn) }

      it "executes undeclared methods via fallback" do
        post tool_action_path("legacy", "legacy_action"), as: :html
        expect(response).to redirect_to(tool_path("legacy"))
      end

      it "executes the public method" do
        post tool_action_path("legacy", "legacy_action"), as: :html

        expect(tool_class.called).to include(:legacy_action)
      end
    end

    describe "deprecation warning" do
      let(:user_email) { "secret-user@example.com" }
      let(:request_note) { "request-note-9f3a" }
      let(:warn_arguments) { [] }

      before do
        email = user_email
        IronAdmin.configure do |config|
          config.current_user { OpenStruct.new(email: email) }
        end
        allow(IronAdmin.deprecator).to receive(:warn) { |*args| warn_arguments.concat(args.map(&:to_s)) }
      end

      context "when the same method is posted twice" do
        before do
          2.times do
            post tool_action_path("legacy", "legacy_action"),
                 params: { note: request_note },
                 as: :html
          end
        end

        it "emits exactly one warning" do
          expect(IronAdmin.deprecator).to have_received(:warn).once
        end

        it "names the tool and the method" do
          expect(warn_arguments).to include(a_string_including("LegacyTool#legacy_action"))
        end

        it "tells you to declare every method the tool dispatches" do
          expect(warn_arguments).to include(
            a_string_including("Declare it, and every other method this tool dispatches, with tool_action")
          )
        end

        it "says dispatching undeclared methods is removed in 1.0" do
          expect(warn_arguments).to include(
            a_string_including("Dispatching undeclared methods is removed in 1.0")
          )
        end

        it "does not include the current user's email" do
          expect(warn_arguments.join).not_to include(user_email)
        end

        it "does not include the request parameter" do
          expect(warn_arguments.join).not_to include(request_note)
        end
      end

      context "when two methods of the same tool are posted twice each" do
        before do
          %w[legacy_action other_action].each do |action_name|
            2.times do
              post tool_action_path("legacy", action_name),
                   params: { note: request_note },
                   as: :html
            end
          end
        end

        it "warns once for each method" do
          messages = warn_arguments.grep(/dispatched without a tool_action declaration/)

          expect(messages).to contain_exactly(
            a_string_including("LegacyTool#legacy_action"),
            a_string_including("LegacyTool#other_action")
          )
        end

        it "does not include the current user's email" do
          expect(warn_arguments.join).not_to include(user_email)
        end

        it "does not include the request parameter" do
          expect(warn_arguments.join).not_to include(request_note)
        end
      end

      context "when two tools define the same method" do
        let(:other_tool_class) do
          Class.new(IronAdmin::Tool) do
            def self.name = "OtherLegacyTool"

            menu label: "Other Legacy"

            def legacy_action
              # bare method on a second tool
            end
          end
        end

        before do
          IronAdmin::ToolRegistry.register(other_tool_class)
          %w[legacy other_legacy].each do |tool_name|
            2.times do
              post tool_action_path(tool_name, "legacy_action"),
                   params: { note: request_note },
                   as: :html
            end
          end
        end

        it "warns once for each tool" do
          messages = warn_arguments.grep(/dispatched without a tool_action declaration/)

          expect(messages).to contain_exactly(
            a_string_including("LegacyTool#legacy_action"),
            a_string_including("OtherLegacyTool#legacy_action")
          )
        end

        it "does not include the current user's email" do
          expect(warn_arguments.join).not_to include(user_email)
        end

        it "does not include the request parameter" do
          expect(warn_arguments.join).not_to include(request_note)
        end
      end

      context "when the memo is reset between dispatches" do
        before do
          post tool_action_path("legacy", "legacy_action"),
               params: { note: request_note },
               as: :html
          IronAdmin::ToolsController.reset_legacy_dispatch_warnings!
          post tool_action_path("legacy", "legacy_action"),
               params: { note: request_note },
               as: :html
        end

        it "warns on the dispatch after the reset" do
          expect(IronAdmin.deprecator).to have_received(:warn).twice
        end
      end
    end

    context "when the method is protected" do
      before { allow(IronAdmin.deprecator).to receive(:warn) }

      it "returns 404" do
        post tool_action_path("legacy", "hidden_helper"), as: :html

        expect(response).to have_http_status(:not_found)
      end

      it "does not execute the method" do
        post tool_action_path("legacy", "hidden_helper"), as: :html

        expect(tool_class.called).not_to include(:hidden_helper)
      end

      it "does not warn" do
        post tool_action_path("legacy", "hidden_helper"), as: :html

        expect(IronAdmin.deprecator).not_to have_received(:warn)
      end
    end

    context "when deprecations are configured to raise" do
      let(:errors) { [] }

      around do |example|
        behavior = IronAdmin.deprecator.behavior
        IronAdmin.deprecator.behavior = :raise
        example.run
      ensure
        IronAdmin.deprecator.behavior = behavior
      end

      before do
        2.times do
          post tool_action_path("legacy", "legacy_action"), as: :html
          errors << nil
        rescue ActiveSupport::DeprecationException
          errors << :raised
        end
      end

      it "raises on every dispatch" do
        expect(errors).to eq(%i[raised raised])
      end

      it "does not execute the method" do
        expect(tool_class.called).not_to include(:legacy_action)
      end
    end

    context "when strict_tool_actions is true" do
      before do
        IronAdmin.configuration.strict_tool_actions = true
        allow(IronAdmin.deprecator).to receive(:warn)
      end

      it "returns 404" do
        post tool_action_path("legacy", "legacy_action"), as: :html

        expect(response).to have_http_status(:not_found)
      end

      it "does not execute the method" do
        post tool_action_path("legacy", "legacy_action"), as: :html

        expect(tool_class.called).not_to include(:legacy_action)
      end

      it "does not warn" do
        post tool_action_path("legacy", "legacy_action"), as: :html

        expect(IronAdmin.deprecator).not_to have_received(:warn)
      end
    end
  end

  describe "a legacy tool that inherits a public method" do
    let(:base_tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "LegacyBaseTool"

        class_attribute :called, default: []

        def shared_ping
          self.class.called = called + [:shared_ping]
        end
      end
    end

    let(:tool_class) do
      Class.new(base_tool_class) do
        def self.name = "LegacyChildTool"
      end
    end

    before do
      base_tool_class
      IronAdmin::ToolRegistry.register(tool_class)
      allow(IronAdmin.deprecator).to receive(:warn)
    end

    it "returns 404" do
      post tool_action_path("legacy_child", "shared_ping"), as: :html

      expect(response).to have_http_status(:not_found)
    end

    it "does not execute the method" do
      post tool_action_path("legacy_child", "shared_ping"), as: :html

      expect(tool_class.called).not_to include(:shared_ping)
    end

    it "does not warn" do
      post tool_action_path("legacy_child", "shared_ping"), as: :html

      expect(IronAdmin.deprecator).not_to have_received(:warn)
    end
  end

  describe "a subclass of ToolsController" do
    let(:tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "HostLegacyTool"

        class_attribute :called, default: []

        def legacy_action
          self.class.called = called + [:legacy_action]
        end
      end
    end

    before do
      IronAdmin::ToolRegistry.register(tool_class)
      allow(IronAdmin.deprecator).to receive(:warn)
    end

    around do |example|
      host_controller = Class.new(IronAdmin::ToolsController) do
        def self.name = "Admin::ToolsController"
      end
      routes = IronAdmin::Engine.routes
      routes.disable_clear_and_finalize = true
      routes.draw do
        post "subclass_tools/:tool_name/:action_name", to: host_controller.action(:execute)
      end
      example.run
    ensure
      IronAdmin::Engine.routes.disable_clear_and_finalize = false
      Rails.application.reload_routes!
    end

    it "executes a legacy method" do
      post "/admin/subclass_tools/host_legacy/legacy_action", as: :html

      expect(tool_class.called).to include(:legacy_action)
    end
  end

  describe "IronAdmin::ToolsController.with_legacy_dispatch_warning" do
    let(:tool_class) { Class.new }
    let(:entered) { Queue.new }
    let(:release) { Queue.new }
    let(:yields) { [] }
    let(:threads) { [] }

    before do
      2.times do
        threads << Thread.new do
          IronAdmin::ToolsController.with_legacy_dispatch_warning(tool_class, :legacy_action) do
            yields << :yielded
            entered << :entered
            release.pop
          end
        end
      end
    end

    after do
      2.times { release << :go }
      threads.each { |thread| thread.join(2) || thread.kill }
    end

    it "the second caller does not enter while the first warns" do
      expect([entered.pop(timeout: 2), entered.pop(timeout: 0.3)]).to eq([:entered, nil])
    end

    it "yields once" do
      entered.pop(timeout: 2)

      expect(yields.size).to eq(1)
    end
  end

  describe "tools that declare actions" do
    let(:tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "MixedTool"

        menu label: "Mixed"

        tool_action :declared_action

        class_attribute :called, default: []

        def declared_action
          self.class.called = called + [:declared_action]
        end

        def helper_action
          self.class.called = called + [:helper_action]
        end
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    context "when the posted name is not declared" do
      before { allow(IronAdmin.deprecator).to receive(:warn) }

      it "returns 404" do
        post tool_action_path("mixed", "helper_action"), as: :html

        expect(response).to have_http_status(:not_found)
      end

      it "does not execute the public method" do
        post tool_action_path("mixed", "helper_action"), as: :html

        expect(tool_class.called).not_to include(:helper_action)
      end

      it "does not warn" do
        post tool_action_path("mixed", "helper_action"), as: :html

        expect(IronAdmin.deprecator).not_to have_received(:warn)
      end
    end

    context "when the posted name is declared" do
      before { allow(IronAdmin.deprecator).to receive(:warn) }

      it "executes the action" do
        post tool_action_path("mixed", "declared_action"), as: :html

        expect(tool_class.called).to include(:declared_action)
      end

      it "does not warn" do
        post tool_action_path("mixed", "declared_action"), as: :html

        expect(IronAdmin.deprecator).not_to have_received(:warn)
      end
    end

    context "when strict_tool_actions is true" do
      before do
        IronAdmin.configuration.strict_tool_actions = true
        allow(IronAdmin.deprecator).to receive(:warn)
      end

      it "executes the declared action" do
        post tool_action_path("mixed", "declared_action"), as: :html

        expect(tool_class.called).to include(:declared_action)
      end

      it "does not warn" do
        post tool_action_path("mixed", "declared_action"), as: :html

        expect(IronAdmin.deprecator).not_to have_received(:warn)
      end
    end
  end

  describe "a subclass of a tool that declares actions" do
    let(:base_tool_class) do
      Class.new(IronAdmin::Tool) do
        def self.name = "BaseSharedTool"

        tool_action :refresh

        class_attribute :called, default: []

        def refresh
          self.class.called = called + [:refresh]
        end
      end
    end

    let(:tool_class) do
      Class.new(base_tool_class) do
        def self.name = "ChildSharedTool"

        def export_csv
          self.class.called = called + [:export_csv]
        end
      end
    end

    before { IronAdmin::ToolRegistry.register(tool_class) }

    context "when the posted name is not declared on the subclass" do
      before { allow(IronAdmin.deprecator).to receive(:warn) }

      it "returns 404" do
        post tool_action_path("child_shared", "export_csv"), as: :html

        expect(response).to have_http_status(:not_found)
      end

      it "does not call the method" do
        post tool_action_path("child_shared", "export_csv"), as: :html

        expect(tool_class.called).not_to include(:export_csv)
      end

      it "does not warn" do
        post tool_action_path("child_shared", "export_csv"), as: :html

        expect(IronAdmin.deprecator).not_to have_received(:warn)
      end
    end

    context "when the posted name is an inherited declared action" do
      before { allow(IronAdmin.deprecator).to receive(:warn) }

      it "executes the action" do
        post tool_action_path("child_shared", "refresh"), as: :html

        expect(tool_class.called).to include(:refresh)
      end

      it "does not warn" do
        post tool_action_path("child_shared", "refresh"), as: :html

        expect(IronAdmin.deprecator).not_to have_received(:warn)
      end
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

    it "renders the action as a theme secondary button" do
      get tool_path("show_test"), as: :html

      expect(response.parsed_body.at_css("form[action$='/visible_action'] button")[:class].split)
        .to eq(IronAdmin::Form::ControlClasses.button(IronAdmin.configuration.theme, :secondary).split)
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
