module IronAdmin
  module Resources
    class SluggedResourceResource < IronAdmin::Resource
      menu priority: 99, icon: "key", group: "Tests"

      index_fields :slug, :title
    end
  end
end
