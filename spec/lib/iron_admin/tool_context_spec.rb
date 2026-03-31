# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::ToolContext do
  subject(:context) do
    described_class.new(
      params: params,
      current_user: current_user,
      flash: flash
    )
  end

  let(:params) { ActionController::Parameters.new(name: "test") }
  let(:current_user) { create(:user) }
  let(:flash) { ActionDispatch::Flash::FlashHash.new }

  describe "#initialize" do
    it "stores params" do
      expect(context.params).to eq(params)
    end

    it "stores current_user" do
      expect(context.current_user).to eq(current_user)
    end

    it "stores flash" do
      expect(context.flash).to eq(flash)
    end
  end

  describe "#action_params" do
    context "with tool_action params present" do
      let(:params) { ActionController::Parameters.new(tool_action: { name: "test", age: "25" }) }

      it "returns permitted params for given keys" do
        result = context.action_params(:name, :age)
        expect(result).to eq({ name: "test", age: "25" })
      end

      it "only permits specified keys" do
        result = context.action_params(:name)
        expect(result).to eq({ name: "test" })
        expect(result).not_to have_key(:age)
      end
    end

    context "without tool_action params" do
      let(:params) { ActionController::Parameters.new({}) }

      it "returns empty hash" do
        expect(context.action_params(:name)).to eq({})
      end
    end
  end
end
