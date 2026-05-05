class License < ApplicationRecord
  belongs_to :user
  has_many :notes, as: :notable, dependent: :destroy

  enum :status, { active: 0, expired: 1, revoked: 2 }

  validates :license_key, presence: true, uniqueness: true
end
