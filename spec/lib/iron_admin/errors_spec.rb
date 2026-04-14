# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Error do
  it "inherits from StandardError" do
    expect(described_class).to be < StandardError
  end
end

RSpec.describe IronAdmin::RecordNotFound do
  it "inherits from IronAdmin::Error" do
    expect(described_class).to be < IronAdmin::Error
  end

  it "can be raised with a message" do
    expect { raise described_class, "User not found" }
      .to raise_error(described_class, "User not found")
  end
end

RSpec.describe IronAdmin::Rollback do
  it "inherits from IronAdmin::Error" do
    expect(described_class).to be < IronAdmin::Error
  end
end
