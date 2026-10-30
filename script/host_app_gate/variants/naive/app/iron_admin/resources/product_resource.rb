module IronAdmin
  module Resources
    class ProductResource < IronAdmin::Resource
      searchable :name
      filter :status, type: :select, options: Product.statuses.keys
      field :category, type: :select, options: %w[kitchen office garden]
      index_fields :name, :status, :category, :price

      bulk_action :archive do |records|
        records.each { |product| product.update!(status: :archived, archived_at: Time.current) }
      end

      policy do
        allow :read
        allow :create, :update, :destroy, if: ->(user) { user&.admin? }
      end
    end
  end
end
