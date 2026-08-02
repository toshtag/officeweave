# 文書の分類。
class DocumentCategory < ApplicationRecord
  belongs_to :organization

  has_many :documents, dependent: :nullify

  include OrganizationScopedCode

  validates :name, presence: true, length: { maximum: 100 }

  scope :ordered, -> { order(:position, :name) }
end
