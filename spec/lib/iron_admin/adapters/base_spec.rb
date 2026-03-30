# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::Adapters::Base do
  subject(:adapter) { described_class.new(User) }

  describe "#initialize" do
    it "stores the model class" do
      expect(adapter.model_class).to eq(User)
    end
  end

  describe "schema introspection" do
    %i[columns column_names enums attachments rich_text_attributes].each do |method|
      it "raises NotImplementedError for ##{method}" do
        expect { adapter.public_send(method) }.to raise_error(NotImplementedError)
      end
    end

    it "raises NotImplementedError for #associations with kind" do
      expect { adapter.associations(:belongs_to) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #associations without kind" do
      expect { adapter.associations }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #association with name" do
      expect { adapter.association(:user) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #has_column?" do
      expect { adapter.has_column?(:name) }.to raise_error(NotImplementedError)
    end
  end

  describe "naming" do
    %i[resource_name human_name table_name].each do |method|
      it "raises NotImplementedError for ##{method}" do
        expect { adapter.public_send(method) }.to raise_error(NotImplementedError)
      end
    end
  end

  describe "query building" do
    %i[all count].each do |method|
      it "raises NotImplementedError for ##{method}" do
        expect { adapter.public_send(method) }.to raise_error(NotImplementedError)
      end
    end

    it "raises NotImplementedError for #find" do
      expect { adapter.find(1) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #find_by" do
      expect { adapter.find_by(name: "x") }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #filter" do
      expect { adapter.filter(nil, :name, "x") }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #order_by" do
      expect { adapter.order_by(nil, :name, :asc) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #limit" do
      expect { adapter.limit(nil, 10) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #preload" do
      expect { adapter.preload(nil, [:user]) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #distinct_values" do
      expect { adapter.distinct_values(:name) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #pluck" do
      expect { adapter.pluck(nil, :id) }.to raise_error(NotImplementedError)
    end
  end

  describe "search" do
    it "raises NotImplementedError for #search_column" do
      expect { adapter.search_column(nil, :name, "query") }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #search_columns" do
      expect { adapter.search_columns(nil, [:name], "query") }.to raise_error(NotImplementedError)
    end
  end

  describe "CRUD" do
    %i[build].each do |method|
      it "raises NotImplementedError for ##{method}" do
        expect { adapter.public_send(method) }.to raise_error(NotImplementedError)
      end
    end

    it "raises NotImplementedError for #save" do
      expect { adapter.save(nil) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #update" do
      expect { adapter.update(nil, {}) }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for #destroy!" do
      expect { adapter.destroy!(nil) }.to raise_error(NotImplementedError)
    end
  end

  describe "transactions" do
    it "raises NotImplementedError for #transaction" do
      expect { adapter.transaction { nil } }.to raise_error(NotImplementedError)
    end
  end

  describe "scope manipulation" do
    it "raises NotImplementedError for #unscope_column" do
      expect { adapter.unscope_column(nil, :deleted_at) }.to raise_error(NotImplementedError)
    end
  end

  describe "batch" do
    it "raises NotImplementedError for #find_each" do
      expect { adapter.find_each(nil) { nil } }.to raise_error(NotImplementedError)
    end
  end
end
