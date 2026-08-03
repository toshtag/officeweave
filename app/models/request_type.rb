# 申請の種別。休暇届や経費精算など、手続きの種類ごとに用意する。
#
# 使わなくなった種別は削除せず、新しい申請を受け付けない状態にする。
# 削除すると、過去の申請が何の手続きだったのか分からなくなる。
class RequestType < ApplicationRecord
  belongs_to :organization

  has_many :requests, dependent: :restrict_with_error
  has_many :approval_steps, -> { ordered }, dependent: :destroy, inverse_of: :request_type

  accepts_nested_attributes_for :approval_steps, allow_destroy: true

  include OrganizationScopedCode

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2_000 }

  # 段を持たない種別を作らない。1 段も無い種別は、提出しても誰も担当しない。
  # 指定が無い場合の担当は、段を持つ前の「承認部門なし」と同じ管理者とする。
  before_validation :ensure_first_step

  scope :ordered, -> { order(:position, :name) }
  scope :active, -> { where(active: true) }

  # この種別の申請を承認できる立場かどうか。
  #
  # いずれかの段を担当していれば、その種別の申請を参照できる。
  # 実際に決裁できるかどうかは、現在の段が決める。
  def approvable_by?(user)
    return true if user.administrator?

    approval_steps.any? { |step| step.approvable_by?(user) }
  end

  private
    def ensure_first_step
      return if approval_steps.any? { |step| !step.marked_for_destruction? }

      approval_steps.build(position: 10)
    end
end
