# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::ThemeHelper, type: :helper do
  describe "#t" do
    context "outside a request" do
      it "returns the default theme" do
        expect(helper.t).to equal(IronAdmin.configuration.theme)
      end
    end

    context "when the request resolved a theme" do
      let(:midnight) { IronAdmin.configuration.register_theme(:midnight) }

      before { IronAdmin::Current.theme = midnight }

      it "returns that theme" do
        expect(helper.t).to equal(midnight)
      end
    end
  end
end
