# 申請へ写した承認経路の段。
#
# 提出の時点の段を写して残す。種別の段（ApprovalStep）を後から変えても、
# この申請が通る経路は変わらない。
#
# 承認した段には、承認者と時刻を残す。誰がどの段を通したのかは、
# 決裁の履歴とこの記録の両方から辿れる。
class RequestApprovalStep < ApplicationRecord
  include ApprovalStepBehavior

  belongs_to :request
  belongs_to :approver, class_name: "User", optional: true

  validates :position, uniqueness: { scope: :request_id }
  validate :approver_department_must_be_in_same_organization

  scope :approved, -> { where.not(approved_at: nil) }

  def approved? = approved_at.present?

  # 承認したことを残す。すでに承認済みの段は変えない。
  def record_approval!(actor:, at: Time.current)
    return if approved?

    update!(approver: actor, approved_at: at)
  end

  private
    def approver_department_must_be_in_same_organization
      return if approver_department.nil? || request.nil?
      return if approver_department.organization_id == request.organization_id

      errors.add(:approver_department, :different_organization)
    end
end
