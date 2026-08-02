# 承認の段。
#
# 種別ごとに、承認を担当する部門を並べる。部門を指定しない段は管理者が
# 担当する。これは、段を持つ前の「承認部門なし」と同じ扱いである。
#
# 並びは position で表す。値は連続していなくてよい。間へ段を足せるように
# するためであり、部門や種別の並びと同じ考え方である。
class ApprovalStep < ApplicationRecord
  belongs_to :request_type
  belongs_to :approver_department, class_name: "Department", optional: true

  validates :position, presence: true,
                       uniqueness: { scope: :request_type_id },
                       numericality: { only_integer: true }
  validate :approver_department_must_be_in_same_organization

  # 最後の段は消せない。1 段も無い種別は、提出しても誰も担当しない。
  before_destroy :preserve_last_step

  scope :ordered, -> { order(:position, :id) }

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

  private
    # 組織をまたぐ参照を作らない。種別と同じ組織の部門だけを指定できる。
    def approver_department_must_be_in_same_organization
      return if approver_department.nil? || request_type.nil?
      return if approver_department.organization_id == request_type.organization_id

      errors.add(:approver_department, :different_organization)
    end

    def preserve_last_step
      return if request_type.nil?
      return if request_type.approval_steps.where.not(id: id).exists?

      errors.add(:base, :last_approval_step)
      throw(:abort)
    end
end
