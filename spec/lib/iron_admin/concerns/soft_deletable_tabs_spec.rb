# frozen_string_literal: true

require "rails_helper"
require "iron_admin/adapters/mongoid"

RSpec.describe IronAdmin::Concerns::SoftDeletable do
  describe "IronAdmin soft-delete tabs" do
    describe "HTTP resource" do
      let(:resource) do
        Class.new(IronAdmin::Resource) do
          self.adapter_class = :http

          def self.name = "IronAdmin::Resources::RemoteWidgetResource"
          def self.resource_name = "remote_widgets"
        end
      end

      before do
        IronAdmin.configuration.http_base_url = "https://api.example.com/v1"
        stub_request(:get, %r{https://api\.example\.com/v1/remote_widgets}).to_return(
          status: 200,
          body: [{ id: 1, name: "Widget", deleted_at: nil }].to_json,
          headers: { "Content-Type" => "application/json" }
        )
        resource.register_soft_delete_features
      end

      it "skips unscope tabs and still registers restore" do
        names = resource.all_scopes.map { |scope| scope.is_a?(Symbol) ? scope : scope[:name] }

        expect(names).not_to include(:with_deleted, :only_deleted)
        expect(resource.soft_delete?).to be(true)
        expect(resource.defined_actions.pluck(:name)).to include(:restore)
      end
    end

    describe IronAdmin::Adapters::Base do
      subject(:adapter) { described_class.new(User) }

      it "does not support soft-delete tabs" do
        expect(adapter.supports_soft_delete_tabs?).to be(false)
      end

      it "raises NotImplementedError from only_soft_deleted" do
        expect { adapter.only_soft_deleted(User.all, :deleted_at) }.to raise_error(NotImplementedError)
      end
    end

    describe IronAdmin::Adapters::ActiveRecord do
      subject(:adapter) { described_class.new(License) }

      it "supports soft-delete tabs" do
        expect(adapter.supports_soft_delete_tabs?).to be(true)
      end

      it "keeps only rows whose column is present" do
        user = create(:user)
        kept = create(:license, user: user, status: "active", expires_at: Time.current)
        missing = create(:license, user: user, status: "active", expires_at: nil)
        result = adapter.only_soft_deleted(License.where(expires_at: nil), :expires_at)

        expect(result).to include(kept)
        expect(result).not_to include(missing)
      end
    end

    describe IronAdmin::Adapters::Mongoid do
      subject(:adapter) { described_class.new(model_class) }

      let(:mongoid_boolean_class) { Object }

      let(:model_class) do
        fields = {
          "_id" => double("Field", name: "_id", type: Object),
          "name" => double("Field", name: "name", type: String),
          "email" => double("Field", name: "email", type: String),
          "age" => double("Field", name: "age", type: Integer),
          "score" => double("Field", name: "score", type: Float),
          "active" => double("Field", name: "active", type: mongoid_boolean_class),
          "birthday" => double("Field", name: "birthday", type: Date),
          "created_at" => double("Field", name: "created_at", type: DateTime),
          "metadata" => double("Field", name: "metadata", type: Hash),
        }

        belongs_to_rel = double(
          "BelongsToRelation",
          name: "organization",
          macro: :belongs_to,
          class_name: "Organization",
          foreign_key: "organization_id",
          polymorphic?: false
        )

        has_many_rel = double(
          "HasManyRelation",
          name: "posts",
          macro: :has_many,
          class_name: "Post",
          foreign_key: "user_id",
          polymorphic?: false
        )

        embeds_many_rel = double(
          "EmbedsManyRelation",
          name: "comments",
          macro: :embeds_many,
          class_name: "Comment",
          foreign_key: "commentable_id",
          polymorphic?: false
        )

        double(
          "MongoidModel",
          fields: fields,
          relations: {
            "organization" => belongs_to_rel,
            "posts" => has_many_rel,
            "comments" => embeds_many_rel,
          }
        )
      end

      it "supports soft-delete tabs" do
        expect(adapter.supports_soft_delete_tabs?).to be(true)
      end

      it "drops the column condition and keeps rows whose column is not nil" do
        scope = double("Criteria", selector: { "deleted_at" => nil, "active" => true }, options: {})
        criteria = double("UnscopedCriteria")
        result = double("OnlyDeletedCriteria")
        allow(model_class).to receive(:where).with({ "active" => true }).and_return(criteria)
        allow(criteria).to receive(:where).with({ "deleted_at" => { "$ne" => nil } }).and_return(result)

        expect(adapter.only_soft_deleted(scope, :deleted_at)).to eq(result)
      end
    end
  end
end
