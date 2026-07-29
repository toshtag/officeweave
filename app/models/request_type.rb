# 申請の種別。休暇届や経費精算など、手続きの種類ごとに用意する。
#
# 使わなくなった種別は削除せず、新しい申請を受け付けない状態にする。
# 削除すると、過去の申請が何の手続きだったのか分からなくなる。
class RequestType < ApplicationRecord
  belongs_to :organization
  belongs_to :approver_department, class_name: "Department", optional: true

  has_many :requests, dependent: :restrict_with_error

  normalizes :code, with: ->(value) { value.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 50 },
                   format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ },
                   uniqueness: { scope: :organization_id }
  validates :description, length: { maximum: 2_000 }
  validate :approver_department_must_be_in_same_organization

  scope :ordered, -> { order(:position, :name) }
  scope :active, -> { where(active: true) }

  # この種別の申請を承認できる利用者かどうか。
  # 承認部門が未指定の場合は、管理者だけが承認する。
  def approvable_by?(user)
    return true if user.administrator?
    return false if approver_department_id.nil?

    user.memberships.exists?(department_id: approver_department_id)
  end

  private
    def approver_department_must_be_in_same_organization
      return if approver_department.nil? || approver_department.organization_id == organization_id

      errors.add(:approver_department, :different_organization)
    end
end
