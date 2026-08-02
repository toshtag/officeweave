# 承認の段。
#
# 種別ごとに、承認を担当する部門を並べる。部門を指定しない段は管理者が
# 担当する。これは、段を持つ前の「承認部門なし」と同じ扱いである。
#
# 並びは position で表す。値は連続していなくてよい。間へ段を足せるように
# するためであり、部門や種別の並びと同じ考え方である。
class ApprovalStep < ApplicationRecord
  include ApprovalStepBehavior

  belongs_to :request_type

  validates :position, uniqueness: { scope: :request_type_id }
  validate :approver_department_must_be_in_same_organization

  # 最後の段は消せない。1 段も無い種別は、提出しても誰も担当しない。
  before_destroy :preserve_last_step

  # 申請へ写すための値。写した先の表と同じ意味の列だけを渡す。
  def snapshot_attributes = { position: position, approver_department_id: approver_department_id }

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
