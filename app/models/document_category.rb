# 文書の分類。
class DocumentCategory < ApplicationRecord
  belongs_to :organization

  has_many :documents, dependent: :nullify

  normalizes :code, with: ->(value) { value.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 50 },
                   format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ },
                   uniqueness: { scope: :organization_id }

  scope :ordered, -> { order(:position, :name) }
end
