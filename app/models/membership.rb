# 利用者と部門の結びつき。
class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :department

  validates :user_id, uniqueness: { scope: :department_id }
  belongs_to_same_organization :department, of: :user

  # 主たる所属は利用者ごとに 1 件までとする。
  # データベース側にも部分一意索引を置いているが、
  # 画面へ理由を返せるようにここでも切り替える。
  before_save :demote_other_primary_memberships, if: -> { primary? && primary_changed? }

  scope :primary, -> { where(primary: true) }

  private
    def demote_other_primary_memberships
      Membership.where(user_id: user_id).where.not(id: id).update_all(primary: false)
    end
end
