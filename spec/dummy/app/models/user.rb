class User < ApplicationRecord
  has_many :licenses
  has_one :profile
  has_many :notes, as: :notable, dependent: :destroy

  accepts_nested_attributes_for :licenses, allow_destroy: true

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
