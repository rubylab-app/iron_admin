# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe "IronAdmin::Audit", type: :request do
  before do
    IronAdmin.reset_configuration!
    IronAdmin::ResourceRegistry.reset!
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::AuditLog.clear!
  end

  describe "GET /audit" do
    it "returns successful response" do
      get iron_admin.audit_path

      expect(response).to have_http_status(:ok)
    end

    it "shows disabled warning when audit is disabled" do
      get iron_admin.audit_path

      expect(response.body).to include("Audit logging is currently disabled")
    end

    it "gives the disabled warning the theme's alert_shadow" do
      IronAdmin.configuration.theme.alert_shadow = "shadow-md"
      get iron_admin.audit_path

      expect(response.parsed_body.at_css("div.gap-3.p-4.mb-6")[:class].split).to include("shadow-md")
    end

    it "does not show disabled warning when audit is enabled" do
      IronAdmin.configure { |c| c.audit_enabled = true }

      get iron_admin.audit_path

      expect(response.body).not_to include("Audit logging is currently disabled")
    end

    it "shows empty state when no entries" do
      get iron_admin.audit_path

      expect(response.body).to include("No audit log entries found")
    end

    context "with audit entries" do
      before do
        IronAdmin.configure { |c| c.audit_enabled = true }

        # Create some audit entries
        IronAdmin::AuditLog.log(OpenStruct.new(
                                  user: OpenStruct.new(email: "admin@example.com"),
                                  action: :create,
                                  resource: "UserResource",
                                  record_id: 1,
                                  changes: { name: [nil, "John Doe"] },
                                  ip_address: "127.0.0.1"
                                ))

        IronAdmin::AuditLog.log(OpenStruct.new(
                                  user: OpenStruct.new(email: "admin@example.com"),
                                  action: :update,
                                  resource: "UserResource",
                                  record_id: 1,
                                  changes: { name: ["John Doe", "Jane Doe"] },
                                  ip_address: "192.168.1.1"
                                ))
      end

      it "displays audit entries" do
        get iron_admin.audit_path

        expect(response.body).to include("admin@example.com")
        expect(response.body).to include("Create")
        expect(response.body).to include("Update")
        expect(response.body).to include("UserResource")
      end

      describe "the table frame, which scrolls sideways on a narrow screen" do
        subject(:frame) do
          get iron_admin.audit_path
          response.parsed_body.at_css("table").parent
        end

        it "fades the edge the table can still scroll toward" do
          expect(frame[:class].split).to include("overflow-x-auto", "cp-scroll-fade")
        end

        # The fade masks the scrolling box, so the card's border sits on a box that does not scroll.
        it "sits in the card, whose border the fade leaves alone" do
          expect(frame.parent[:class].split).to include(*IronAdmin.current_theme.card_border.split, *IronAdmin.current_theme.border_radius.split)
        end

        it "rounds its corners like the card" do
          expect(frame[:class].split).to include("rounded-[inherit]")
        end
      end

      it "keeps each changes summary on one line, so a table narrower than its columns keeps short rows" do
        get iron_admin.audit_path

        expect(response.parsed_body.css("td details > summary").map { |summary| summary[:class].split }).to all(include("whitespace-nowrap"))
      end

      it "displays IP addresses" do
        get iron_admin.audit_path

        expect(response.body).to include("127.0.0.1")
        expect(response.body).to include("192.168.1.1")
      end

      it "filters by resource" do
        IronAdmin::AuditLog.log(OpenStruct.new(
                                  user: OpenStruct.new(email: "admin@example.com"),
                                  action: :create,
                                  resource: "PostResource",
                                  record_id: 10,
                                  changes: {},
                                  ip_address: "10.0.0.1"
                                ))

        get iron_admin.audit_path(resource: "UserResource")

        expect(response.body).to include("UserResource")
        # PostResource entry should still appear in filter results since we query all
        # The filter only affects @entries
      end

      it "filters by action" do
        get iron_admin.audit_path(action_filter: "create")

        expect(response.body).to include("Create")
      end

      context "with a custom action logged" do
        subject(:action_options) do
          get iron_admin.audit_path
          response.parsed_body.css("select[name=action_filter] option").pluck(:value)
        end

        before do
          IronAdmin::AuditLog.log(OpenStruct.new(user: nil, action: :deactivate, resource: "UserResource",
                                                 record_id: 1, changes: {}, ip_address: "127.0.0.1"))
        end

        it "offers only the logged actions in the action filter" do
          expect(action_options).to eq(["", "create", "deactivate", "update"])
        end
      end
    end
  end

  describe "GET /audit user labels with memory storage" do
    subject(:user_cell) do
      get iron_admin.audit_path
      response.parsed_body.at_css("tbody tr td:nth-child(2)").text.strip
    end

    before do
      IronAdmin.configure { |c| c.audit_enabled = true }
      IronAdmin::AuditLog.log(OpenStruct.new(user: OpenStruct.new(id: 5, email: "admin@example.com"), action: :create,
                                             resource: "UserResource", record_id: 1, changes: {}, ip_address: "127.0.0.1"))
    end

    it "shows the user's email without audit_user_labels" do
      expect(user_cell).to eq("admin@example.com")
    end

    context "with audit_user_labels configured" do
      before { IronAdmin.configure { |c| c.audit_user_labels { |identifiers| identifiers.index_with { "Admin Five" } } } }

      it "shows the configured label" do
        expect(user_cell).to eq("Admin Five")
      end
    end

    context "when audit_user_labels does not label the user" do
      before { IronAdmin.configure { |c| c.audit_user_labels { |_identifiers| {} } } }

      it "shows the user's email" do
        expect(user_cell).to eq("admin@example.com")
      end
    end

    context "when the audit_user_labels block raises" do
      before { IronAdmin.configure { |c| c.audit_user_labels { |_identifiers| raise "boom" } } }

      it "shows the user's email" do
        expect(user_cell).to eq("admin@example.com")
      end
    end
  end

  describe "GET /audit resource labels" do
    let(:document) do
      get iron_admin.audit_path(filters)
      response.parsed_body
    end
    let(:filters) { {} }
    let(:resource_cells) { document.css("tbody tr").map { |row| row.css("td")[3].text.strip } }
    let(:resource_options) do
      document.css("select[name=resource] option").to_h { |option| [option[:value], option.text.strip] }
    end

    before do
      IronAdmin.configure { |c| c.audit_enabled = true }
      [IronAdmin::Resources::UserResource.name, "Legacy::ArchivedResource"].each do |resource|
        IronAdmin::AuditLog.log(OpenStruct.new(user: nil, action: :create, resource: resource, record_id: 1,
                                               changes: {}, ip_address: "127.0.0.1"))
      end
    end

    it "shows the label of a registered resource in the Resource column" do
      expect(resource_cells).to include("Users")
    end

    it "shows the stored value of a resource that is not registered" do
      expect(resource_cells).to include("Legacy::ArchivedResource")
    end

    it "labels registered resources in the Resource filter" do
      expect(resource_options[IronAdmin::Resources::UserResource.name]).to eq("Users")
    end

    it "offers a logged resource that is not registered under its stored value" do
      expect(resource_options["Legacy::ArchivedResource"]).to eq("Legacy::ArchivedResource")
    end

    context "when filtering by a resource that is not registered" do
      let(:filters) { { resource: "Legacy::ArchivedResource" } }

      it "keeps it selected in the Resource filter" do
        expect(document.at_css("select[name=resource] option[selected]")[:value]).to eq("Legacy::ArchivedResource")
      end
    end
  end

  describe "GET /audit filter labels" do
    subject(:labelled_controls) do
      get iron_admin.audit_path
      form = response.parsed_body.at_css("form")
      form.css("label").to_h { |label| [label.text.strip, label[:for] && form.at_css("[id='#{label[:for]}']")&.[](:name)] }
    end

    before do
      IronAdmin.configure { |c| c.audit_enabled = true }
      IronAdmin::AuditLog.log(OpenStruct.new(user: nil, action: :create, resource: "UserResource", record_id: 1,
                                             changes: {}, ip_address: "127.0.0.1"))
    end

    it "associates each label with its control" do
      expect(labelled_controls).to eq("Resource" => "resource", "Action" => "action_filter", "From" => "from", "To" => "to")
    end
  end

  describe "GET /audit filter row" do
    subject(:filter_row) do
      get iron_admin.audit_path
      response.parsed_body.at_css("form")
    end

    before do
      IronAdmin.configure { |c| c.audit_enabled = true }
      IronAdmin::AuditLog.log(OpenStruct.new(user: nil, action: :create, resource: "UserResource", record_id: 1,
                                             changes: {}, ip_address: "127.0.0.1"))
    end

    it "gives the selects, date inputs, Filter button and Clear link one height, so they line up" do
      controls = filter_row.css("select, input[type=date], button, a")
      expect(controls.map { |control| control[:class].split.include?("h-9") }).to all(be(true))
    end

    it "draws the Clear link as a secondary button, like the forms' Cancel" do
      expect(filter_row.at_css("a")[:class].split).to eq(IronAdmin::Resources::Styles.secondary_button(IronAdmin.current_theme).split)
    end

    it "insets the text of the date inputs like the selects" do
      left_paddings = filter_row.css("select, input[type=date]").map { |control| control[:class][/(?<![\w-])p[xl]-([\d.]+)/, 1] }
      expect(left_paddings.uniq).to eq(["3"])
    end
  end

  describe "GET /audit with database storage" do
    subject(:page) do
      get iron_admin.audit_path(filters)
      response
    end

    let(:filters) { {} }

    before do
      IronAdmin.configure do |c|
        c.audit_enabled = true
        c.audit_storage = :database
      end
      IronAdmin::AuditEntry.delete_all
      IronAdmin::AuditEntry.create!(user_identifier: "7", action: "create", resource: "UserResource", record_id: 1,
                                    record_changes: { "name" => [nil, "John Doe"] }, ip_address: "127.0.0.1",
                                    created_at: Time.zone.parse("2026-10-24 09:00"))
      IronAdmin::AuditEntry.create!(user_identifier: "7", action: "update", resource: "UserResource", record_id: 1,
                                    record_changes: { "name" => ["John Doe", "Jane Doe"] }, ip_address: "127.0.0.1",
                                    created_at: Time.zone.parse("2026-10-25 18:30"))
    end

    after { IronAdmin::AuditEntry.delete_all }

    it "renders the entries" do
      expect(page).to have_http_status(:ok)
    end

    # The format of the other dates of the admin, such as a datetime field's.
    it "shows when each entry happened, as the other pages show dates" do
      expect(page.parsed_body.css("tbody time").map { |time| time.text.strip }).to include("Oct 25, 2026 at 6:30 PM")
    end

    it "gives the exact time to machines and on hover" do
      time = page.parsed_body.css("tbody time").find { |node| node.text.include?("Oct 25") }
      expect([time[:datetime], time[:title]]).to eq(["2026-10-25T18:30:00Z", "2026-10-25 18:30:00 UTC"])
    end

    it "shows the stored user identifier" do
      expect(page.body).to match(%r{<td[^>]*>\s*7\s*</td>})
    end

    context "with audit_user_labels configured" do
      subject(:user_cells) { page.parsed_body.css("tbody tr").map { |row| row.css("td")[1].text.strip } }

      let(:lookups) { [] }
      let!(:jane) { create(:user, name: "Jane Doe") }

      before do
        IronAdmin::AuditEntry.update_all(user_identifier: jane.id.to_s)
        IronAdmin::AuditEntry.create!(user_identifier: "999999", action: "destroy", resource: "UserResource",
                                      record_id: 2, ip_address: "127.0.0.1", created_at: Time.zone.parse("2026-10-23 08:00"))
        IronAdmin.configure do |c|
          c.audit_user_labels do |identifiers|
            lookups << identifiers
            User.where(id: identifiers).pluck(:id, :name).to_h
          end
        end
      end

      it "shows each user's label" do
        expect(user_cells.first(2)).to eq(["Jane Doe", "Jane Doe"])
      end

      it "shows the identifier of a user that no longer exists" do
        expect(user_cells.last).to eq("999999")
      end

      it "looks up every user on the page in one call" do
        page

        expect(lookups).to eq([[jane.id.to_s, "999999"]])
      end
    end

    context "when the audit_user_labels block raises" do
      before { IronAdmin.configure { |c| c.audit_user_labels { |_identifiers| raise "users table is gone" } } }

      it "still renders the entries" do
        expect(page).to have_http_status(:ok)
      end

      it "shows the stored user identifier" do
        expect(page.body).to match(%r{<td[^>]*>\s*7\s*</td>})
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:error)
        page

        expect(Rails.logger).to have_received(:error).with("[IronAdmin] RuntimeError: users table is gone")
      end
    end

    context "with an entry logged without a user" do
      before { IronAdmin::AuditEntry.update_all(user_identifier: "") }

      it "shows Unknown instead of an empty cell" do
        expect(page.parsed_body.css("tbody tr").map { |row| row.css("td")[1].text.strip }.uniq).to eq(["Unknown"])
      end
    end

    it "shows the recorded changes" do
      expect(page.body).to include("Jane Doe")
    end

    it "lists the newest entry first" do
      expect(page.body.index("2026-10-25 18:30:00")).to be < page.body.index("2026-10-24 09:00:00")
    end

    context "when filtering up to a date" do
      let(:filters) { { to: "2026-10-25" } }

      it "includes entries from the whole day" do
        expect(page.body).to include("2026-10-25 18:30:00")
      end
    end

    context "when the filters match no entries" do
      let(:filters) { { action_filter: "destroy" } }

      it "keeps the filter form so the filters can be cleared" do
        expect(page.body).to include("Clear</a>")
      end

      it "keeps the selected action in the action filter" do
        expect(page.parsed_body.at_css("select[name=action_filter] option[selected]")[:value]).to eq("destroy")
      end
    end

    context "with a custom action logged" do
      subject(:action_options) do
        page.parsed_body.css("select[name=action_filter] option").to_h { |option| [option[:value], option.text] }
      end

      before do
        IronAdmin::AuditEntry.create!(user_identifier: "7", action: "send_now", resource: "UserResource",
                                      record_id: 1, ip_address: "127.0.0.1")
      end

      it "offers only the logged actions in the action filter" do
        expect(action_options.keys).to eq(["", "create", "send_now", "update"])
      end

      it "labels each action in a readable way" do
        expect(action_options["send_now"]).to eq("Send now")
      end
    end

    context "with a resource that is not registered" do
      subject(:resource_options) { page.parsed_body.css("select[name=resource] option").pluck(:value) }

      it "offers its stored value in the resource filter" do
        expect(resource_options).to include("UserResource")
      end
    end

    context "with an invalid date" do
      let(:filters) { { from: "2026-13-45" } }

      it "ignores the date" do
        expect(page.body).to include("2026-10-24 09:00:00")
      end
    end
  end

  describe "changes recorded for a resource update" do
    subject(:recorded_changes) do
      patch iron_admin.resource_path("documents", document),
            params: { record: { title: "Renamed", password_hash: "new_secret" } }
      IronAdmin::AuditEntry.last.record_changes
    end

    let(:document) { create(:document, title: "Original", password_hash: "old_secret") }

    before do
      IronAdmin::ResourceRegistry.register(IronAdmin::Resources::DocumentResource)
      IronAdmin.configure do |c|
        c.audit_enabled = true
        c.audit_storage = :database
      end
      IronAdmin::AuditEntry.delete_all
    end

    after { IronAdmin::AuditEntry.delete_all }

    it "masks password fields" do
      expect(recorded_changes["password_hash"]).to eq("[FILTERED]")
    end

    it "keeps the other changes" do
      expect(recorded_changes["title"]).to eq(%w[Original Renamed])
    end

    it "passes the masked changes to the on_action callback" do
      received = nil
      IronAdmin.configure { |c| c.on_action { |event| received = event.changes } }
      recorded_changes

      expect(received["password_hash"]).to eq("[FILTERED]")
    end

    context "when the host app filters a parameter" do
      around do |example|
        original = Rails.application.config.filter_parameters
        Rails.application.config.filter_parameters = original + [:title]
        example.run
      ensure
        Rails.application.config.filter_parameters = original
      end

      it "masks it too" do
        expect(recorded_changes["title"]).to eq("[FILTERED]")
      end
    end
  end
end
