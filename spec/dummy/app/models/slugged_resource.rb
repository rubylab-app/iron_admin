# Single-column custom-PK model used by the dummy app to exercise
# Scopeable#find_record's non-composite path when `primary_key` differs
# from `:id` (e.g., `self.primary_key = :slug`).
class SluggedResource < ApplicationRecord
  self.primary_key = :slug
end
