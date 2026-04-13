require "rails_helper"

class TestDashboard < IronAdmin::Dashboard
  metric :total_users do
    42
  end

  metric :revenue, format: :currency do
    1500.50
  end

  chart :users_over_time, type: :line do
    { "Jan" => 10, "Feb" => 20 }
  end

  chart :orders_by_status, type: :bar, colors: ["#10b981", "#3b82f6"] do
    { "Pending" => 5, "Completed" => 15 }
  end

  recent :users, limit: 5, scope: -> { order(created_at: :desc) }
end

RSpec.describe IronAdmin::Dashboard do
  describe "metrics" do
    it "stores metric definitions" do
      expect(TestDashboard.defined_metrics.length).to eq(2)
    end

    it "evaluates metric value" do
      metric = TestDashboard.defined_metrics.first
      expect(metric[:block].call).to eq(42)
    end

    it "stores format option" do
      metric = TestDashboard.defined_metrics.last
      expect(metric[:format]).to eq(:currency)
    end
  end

  describe "charts" do
    it "stores chart definitions" do
      expect(TestDashboard.defined_charts.length).to eq(2)
      expect(TestDashboard.defined_charts.first[:type]).to eq(:line)
    end

    it "stores colors as nil when not specified" do
      expect(TestDashboard.defined_charts.first[:colors]).to be_nil
    end

    it "stores per-chart colors when specified" do
      expect(TestDashboard.defined_charts.last[:colors]).to eq(["#10b981", "#3b82f6"])
    end

    it "stores label as nil when not specified" do
      expect(TestDashboard.defined_charts.first[:label]).to be_nil
    end

    it "stores label when specified" do
      dashboard_class = Class.new(IronAdmin::Dashboard) do
        chart :projects_by_status, type: :bar, label: "Projects by Status" do
          { "Draft" => 2, "Active" => 5 }
        end
      end

      chart = dashboard_class.defined_charts.first
      expect(chart[:label]).to eq("Projects by Status")
    end
  end

  describe "recents" do
    it "stores recent definitions" do
      expect(TestDashboard.defined_recents.length).to eq(1)
      expect(TestDashboard.defined_recents.first[:limit]).to eq(5)
    end
  end
end
