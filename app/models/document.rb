# 組織で共有する文書。
class Document < ApplicationRecord
  belongs_to :organization
  belongs_to :document_category, optional: true
  belongs_to :author, class_name: "User"

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 100_000 }
  validate :category_must_be_in_same_organization

  scope :recently_updated, -> { order(updated_at: :desc, id: :desc) }
  scope :in_category, ->(category_id) { where(document_category_id: category_id) if category_id.present? }

  # 作成者と管理者だけが変更できる。
  def editable_by?(user)
    author_id == user.id || user.administrator?
  end

  private
    def category_must_be_in_same_organization
      return if document_category.nil? || document_category.organization_id == organization_id

      errors.add(:document_category, :different_organization)
    end
end
