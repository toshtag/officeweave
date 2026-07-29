# 組織で共有する文書。
class Document < ApplicationRecord
  VISIBILITIES = %w[organization departments].freeze

  # 添付できるファイルの上限。
  # 大きなファイルを共有する用途は想定せず、規程や手順書の補助資料を想定する。
  MAX_ATTACHMENT_SIZE = 20.megabytes
  MAX_ATTACHMENT_COUNT = 10

  belongs_to :organization
  belongs_to :document_category, optional: true
  belongs_to :author, class_name: "User"

  has_many :document_departments, dependent: :destroy
  has_many :departments, through: :document_departments

  has_many_attached :attachments

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 100_000 }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validate :category_must_be_in_same_organization
  validate :departments_required_when_limited
  validate :departments_must_be_in_same_organization
  validate :attachments_must_be_within_limits

  scope :recently_updated, -> { order(updated_at: :desc, id: :desc) }

  # 参照できる文書。
  # 作成者は公開範囲に関わらず自分の文書を参照できる。
  scope :visible_to, ->(user) {
    in_organization = where(organization_id: user.organization_id)

    in_organization
      .where(author_id: user.id)
      .or(in_organization.where(visibility: "organization"))
      .or(in_organization.where(id: DocumentDepartment
        .where(department_id: Membership.where(user_id: user.id).select(:department_id))
        .select(:document_id)))
  }
  scope :in_category, ->(category_id) { where(document_category_id: category_id) if category_id.present? }

  # 作成者と管理者だけが変更できる。
  def editable_by?(user)
    author_id == user.id || user.administrator?
  end

  def limited_to_departments?
    visibility == "departments"
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

    def departments_required_when_limited
      return unless limited_to_departments?
      return if departments.any? || document_departments.any?

      errors.add(:department_ids, :blank)
    end

    def departments_must_be_in_same_organization
      return if departments.all? { |department| department.organization_id == organization_id }

      errors.add(:department_ids, :different_organization)
    end

    def category_must_be_in_same_organization
      return if document_category.nil? || document_category.organization_id == organization_id

      errors.add(:document_category, :different_organization)
    end
end
