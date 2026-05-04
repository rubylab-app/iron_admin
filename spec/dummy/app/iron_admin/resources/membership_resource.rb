module IronAdmin
  module Resources
    class MembershipResource < IronAdmin::Resource
      menu priority: 99, icon: "key", group: "Tests"

      index_fields :account_id, :scope_id, :role
    end
  end
end
