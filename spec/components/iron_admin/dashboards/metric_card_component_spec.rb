require "rails_helper"
require_relative "../../../../app/components/iron_admin/dashboards/metric_card_component"

RSpec.describe IronAdmin::Dashboards::MetricCardComponent, type: :component do
  it "renders metric name and value" do
    result = render_inline(described_class.new(name: :total_users, value: 42, format: :number))

    expect(result.text).to include("Total users")
    expect(result.text).to include("42")
  end

  it "formats currency" do
    result = render_inline(described_class.new(name: :revenue, value: 1500.50, format: :currency))

    expect(result.text).to include("$1,500.50")
  end

  it "exposes icon attribute when provided" do
    component = described_class.new(name: :total_users, value: 42, format: :number, icon: "users")
    expect(component.icon).to eq("users")
  end

  it "has nil icon when not provided" do
    component = described_class.new(name: :total_users, value: 42, format: :number)
    expect(component.icon).to be_nil
  end

  it "renders the heroicon when icon is provided" do
    result = render_inline(described_class.new(name: :total_users, value: 42, format: :number, icon: "users"))

    expect(result.css("svg").size).to eq(1)
  end
end
