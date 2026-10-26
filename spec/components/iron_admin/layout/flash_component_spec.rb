# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Layout::FlashComponent, type: :component do
  subject(:rendered) { render_inline(described_class.new(flash: messages)) }

  def texts(role)
    rendered.css("[role='#{role}']").map { |alert| alert.text.squish }
  end

  context "with a notice" do
    let(:messages) { { notice: "User created." } }

    it "shows it as a status message" do
      expect(texts("status")).to eq(["User created."])
    end

    it "styles it as a success" do
      expect(rendered.at_css("[role='status']")[:class]).to include("bg-green-50")
    end
  end

  context "with an alert" do
    let(:messages) { { alert: "Something went wrong. Please try again." } }

    it "shows it as an alert" do
      expect(texts("alert")).to eq(["Something went wrong. Please try again."])
    end

    it "styles it as an error" do
      expect(rendered.at_css("[role='alert']")[:class]).to include("bg-red-50")
    end
  end

  context "with the success, error, warning and info keys" do
    let(:messages) { { success: "Done", error: "Failed", warning: "Careful", info: "Heads up" } }

    it "renders one alert per message, in order" do
      expect(rendered.css("[role]").map { |alert| alert.text.squish }).to eq(["Done", "Failed", "Careful", "Heads up"])
    end
  end

  context "with string keys, as the session stores them" do
    let(:messages) { { "notice" => "Tag deleted." } }

    it "shows the message" do
      expect(texts("status")).to eq(["Tag deleted."])
    end
  end

  context "with several messages under one key" do
    let(:messages) { { alert: ["First problem", "Second problem"] } }

    it "renders each message" do
      expect(texts("alert")).to eq(["First problem", "Second problem"])
    end
  end

  context "with keys and values that are not messages" do
    let(:messages) { { timedout: true, tracking_event: "signup", notice: "" } }

    it "renders nothing" do
      expect(rendered.children).to be_empty
    end
  end

  context "with an empty flash" do
    let(:messages) { {} }

    it "renders nothing" do
      expect(rendered.children).to be_empty
    end
  end

  describe "container" do
    let(:messages) { { notice: "Saved" } }

    it "is left out of the page Turbo caches for back navigation" do
      expect(rendered.at_css("[data-turbo-temporary]")).to be_present
    end
  end

  context "without an explicit flash" do
    subject(:rendered) { render_inline(described_class.new) }

    before { vc_test_controller.flash[:notice] = "From the request" }

    it "shows the request's flash" do
      expect(rendered.at_css("[role='status']").text.squish).to eq("From the request")
    end
  end
end
