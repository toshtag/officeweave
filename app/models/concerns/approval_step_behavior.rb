# 承認の段が持つ共通の振る舞い。
#
# 種別の段（ApprovalStep）と、申請へ写した経路の段（RequestApprovalStep）は、
# 担当の決め方が同じである。2 か所へ写すと、片方だけが変わり得る。
module ApprovalStepBehavior
  extend ActiveSupport::Concern

  included do
    belongs_to :approver_department, class_name: "Department", optional: true

    scope :ordered, -> { order(:position, :id) }

    validates :position, presence: true, numericality: { only_integer: true }
  end

  # この段の承認を担当できる利用者かどうか。
  #
  # 管理者はすべての段を担当する。段を持つ前から、管理者はすべての種別を
  # 担当していた。その範囲を狭めない。
  def approvable_by?(user)
    return true if user.administrator?
    return false if approver_department_id.nil?

    user.memberships.exists?(department_id: approver_department_id)
  end

  # この段を担当する利用者。部門を指定しない段は管理者とする。
  def approvers(organization)
    scope = organization.users.active

    approver_department_id ? scope.where(id: Membership.where(department_id: approver_department_id)
                                                       .select(:user_id))
                           : scope.where(role: "administrator")
  end
end
