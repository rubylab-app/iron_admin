# Composite-primary-key model used by the dummy app to exercise
# Scopeable#find_record handling of `model.primary_key` arrays.
class Membership < ApplicationRecord
  self.primary_key = %i[account_id scope_id]
end
