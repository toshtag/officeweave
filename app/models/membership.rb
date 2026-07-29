# 利用者と部門の結びつき。
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :department

  validates :user_id, uniqueness: { scope: :department_id }
  validate :user_must_be_in_same_organization

  # 主たる所属は利用者ごとに 1 件までとする。
  # データベース側にも部分一意索引を置いているが、
  # 画面へ理由を返せるようにここでも切り替える。
  before_save :demote_other_primary_memberships, if: -> { primary? && primary_changed? }

  scope :primary, -> { where(primary: true) }

  private
    def user_must_be_in_same_organization
      return if user.nil? || department.nil?
      return if user.organization_id == department.organization_id

      errors.add(:department, :different_organization)
    end

    def demote_other_primary_memberships
      Membership.where(user_id: user_id).where.not(id: id).update_all(primary: false)
    end
end
