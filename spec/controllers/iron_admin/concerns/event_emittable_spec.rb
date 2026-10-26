# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Concerns::EventEmittable do
  let(:controller_class) do
    Class.new(IronAdmin::ApplicationController) do
      include IronAdmin::Concerns::EventEmittable

      public :emit_event
      attr_writer :resource_class

      def iron_admin_current_user
        nil
      end
    end
  end

  let(:controller) do
    controller_class.new.tap do |instance|
      instance.set_request!(ActionDispatch::TestRequest.create)
      instance.resource_class = IronAdmin::Resources::DocumentResource
    end
  end

  let(:documents) { create_list(:document, 3) }

  before do
    IronAdmin.configure { |config| config.audit_enabled = true }
    allow(IronAdmin::Resources::DocumentResource).to receive(:resolved_fields).and_call_original
  end

  describe "#emit_event" do
    context "when called for several records in one request" do
      it "resolves the resource fields once" do
        documents.each { |document| controller.emit_event(:update, document) }
        expect(IronAdmin::Resources::DocumentResource).to have_received(:resolved_fields).once
      end
    end
  end
end
