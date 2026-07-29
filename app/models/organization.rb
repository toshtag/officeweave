# 導入単位となる組織。
# セルフホストでは 1 つの導入につき 1 組織を想定するが、
# 部門と利用者の帰属先を明示するため、独立した記録として持つ。
class Organization < ApplicationRecord
  has_many :departments, dependent: :restrict_with_error
  has_many :users, dependent: :restrict_with_error
  has_many :announcements, dependent: :restrict_with_error
  has_many :events, dependent: :restrict_with_error
  has_many :resources, dependent: :restrict_with_error
  has_many :reservations, dependent: :restrict_with_error
  has_many :request_types, dependent: :restrict_with_error
  has_many :requests, dependent: :restrict_with_error
  has_many :document_categories, dependent: :restrict_with_error
  has_many :documents, dependent: :restrict_with_error

  normalizes :code, with: ->(value) { value.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 50 },
                   format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ },
                   uniqueness: true
end
