# 組織で共有する文書。
class Document < ApplicationRecord
  # 添付できるファイルの上限。
  # 大きなファイルを共有する用途は想定せず、規程や手順書の補助資料を想定する。
  MAX_ATTACHMENT_SIZE = 20.megabytes
  MAX_ATTACHMENT_COUNT = 10

  belongs_to :organization
  belongs_to :document_category, optional: true
  belongs_to :author, class_name: "User"

  has_many_attached :attachments

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 100_000 }
  validate :category_must_be_in_same_organization
  validate :attachments_must_be_within_limits

  scope :recently_updated, -> { order(updated_at: :desc, id: :desc) }
  scope :in_category, ->(category_id) { where(document_category_id: category_id) if category_id.present? }

  # 作成者と管理者だけが変更できる。
  def editable_by?(user)
    author_id == user.id || user.administrator?
  end

  private
    # 受け入れる大きさと件数を明示する。
    # 制限がないと、保存領域が尽きた時点で初めて問題が分かる。
    def attachments_must_be_within_limits
      return unless attachments.attached?

      errors.add(:attachments, :too_many, count: MAX_ATTACHMENT_COUNT) if attachments.size > MAX_ATTACHMENT_COUNT

      attachments.each do |attachment|
        next if attachment.blob.byte_size <= MAX_ATTACHMENT_SIZE

        errors.add(:attachments, :too_large, filename: attachment.filename.to_s,
                                             size: MAX_ATTACHMENT_SIZE / 1.megabyte)
      end
    end

    def category_must_be_in_same_organization
      return if document_category.nil? || document_category.organization_id == organization_id

      errors.add(:document_category, :different_organization)
    end
end
