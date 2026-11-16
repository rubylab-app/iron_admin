# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Resource do
  describe "Hidden field inference" do
    let(:resource) do
      Class.new(IronAdmin::Resource) do
        self.model_class_override = Document

        def self.name
          "HiddenFieldDocumentResource"
        end

        def self.resource_name
          "hidden_field_documents"
        end

        field :secret_code, label: "Code"
      end
    end

    before do
      inferred_fields = [
        IronAdmin::Field.new(:secret_code, type: :text, visible: false, readonly: true),
        IronAdmin::Field.new(:title, type: :text),
      ]
      allow(IronAdmin::FieldInferrer).to receive(:call).and_return(inferred_fields)
    end

    describe ".resolved_fields" do
      it "keeps inferred visible and readonly when the override only sets the label" do
        secret = resource.resolved_fields.find { |field| field.name == :secret_code }

        expect(secret.visible).to be(false)
        expect(secret.readonly).to be(true)
        expect(secret.options[:label]).to eq("Code")
      end
    end

    describe ".auto_inferred_filters" do
      it "excludes an always concealed field" do
        adapter = resource.adapter
        columns = [
          Struct.new(:name, :type).new("secret_code", :string),
          Struct.new(:name, :type).new("title", :string),
        ]
        allow(resource).to receive(:adapter).and_return(adapter)
        allow(adapter).to receive_messages(columns: columns, enums: {})

        names = resource.auto_inferred_filters.pluck(:name)

        expect(names).not_to include(:secret_code)
        expect(names).to include(:title)
      end
    end
  end
end
