# 組織内へ知らせる内容。
#
# 公開範囲は「組織全体」と「指定した部門」の 2 種類とする。
# 個人宛の連絡は、この機能では扱わない。
class Announcement < ApplicationRecord
  VISIBILITIES = %w[organization departments].freeze

  belongs_to :organization
  belongs_to :author, class_name: "User"

  has_many :announcement_departments, dependent: :destroy
  has_many :departments, through: :announcement_departments

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true, length: { maximum: 10_000 }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validate :departments_required_when_limited
  validate :departments_must_be_in_same_organization

  scope :published, -> { where.not(published_at: nil).where(published_at: ..Time.current) }
  scope :recent_first, -> { order(published_at: :desc, created_at: :desc) }

  # 利用者が読める公開済みのお知らせ。
  # 公開範囲が部門指定の場合、その利用者の所属部門と重なるものだけを返す。
  scope :visible_to, ->(user) {
    published
      .where(organization_id: user.organization_id)
      .where(
        arel_table[:visibility].eq("organization").or(
          arel_table[:id].in(
            AnnouncementDepartment
              .where(department_id: Membership.where(user_id: user.id).select(:department_id))
              .select(:announcement_id).arel
          )
        )
      )
  }

  def published?
    published_at.present? && published_at <= Time.current
  end

  def limited_to_departments?
    visibility == "departments"
  end

  private
    def departments_required_when_limited
      return unless limited_to_departments?
      return if departments.any? || announcement_departments.any?

      errors.add(:department_ids, :blank)
    end

    def departments_must_be_in_same_organization
      return if departments.all? { |department| department.organization_id == organization_id }

      errors.add(:department_ids, :different_organization)
    end
end
