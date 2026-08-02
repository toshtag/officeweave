# 承認の委任。
#
# 委任した利用者（delegator）が担当する段を、委任を受けた利用者（delegate）も
# 決裁できるようにする。担当そのものは移さない。委任は期間で切れる。
#
# 期間は日の単位とする。時刻まで扱うと、不在の申し出と噛み合わない。
class ApprovalDelegation < ApplicationRecord
  belongs_to :organization
  belongs_to :delegator, class_name: "User"
  belongs_to :delegate, class_name: "User"

  validates :starts_on, presence: true
  validate :ends_on_must_not_precede_starts_on
  validate :delegate_must_differ_from_delegator
  validate :delegate_must_be_active
  validate :period_must_not_overlap
  belongs_to_same_organization :delegator, :delegate

  # その日に有効な委任。終わりを決めない委任は、始まってから続く。
  scope :active, ->(on: Date.current) {
    where(starts_on: ..on).where(ends_on: on..).or(where(starts_on: ..on).where(ends_on: nil))
  }

  scope :recent_first, -> { order(starts_on: :desc, id: :desc) }

  def active?(on: Date.current)
    starts_on <= on && (ends_on.nil? || ends_on >= on)
  end

  # その利用者が代わりに決裁できる相手。
  def self.delegators_for(user, on: Date.current)
    active(on: on).where(delegate_id: user.id).select(:delegator_id)
  end

  private
    def ends_on_must_not_precede_starts_on
      return if ends_on.nil? || starts_on.nil? || ends_on >= starts_on

      errors.add(:ends_on, :not_after_start)
    end

    def delegate_must_differ_from_delegator
      return if delegate_id.nil? || delegate_id != delegator_id

      errors.add(:delegate, :same_as_delegator)
    end

    def delegate_must_be_active
      return if delegate.nil? || delegate.active?

      errors.add(:delegate, :inactive)
    end

    # 同じ相手への委任が期間で重ならないようにする。
    # 重なっても、できることは変わらない。重複の分だけ読む量が増える。
    def period_must_not_overlap
      return if delegator_id.nil? || delegate_id.nil? || starts_on.nil?

      overlapping = self.class.where(delegator_id: delegator_id, delegate_id: delegate_id)
                              .where.not(id: id)
                              .where(starts_on: ..(ends_on || Date::Infinity.new))
                              .where(ends_on: starts_on..).or(
                                self.class.where(delegator_id: delegator_id, delegate_id: delegate_id)
                                          .where.not(id: id)
                                          .where(starts_on: ..(ends_on || Date::Infinity.new))
                                          .where(ends_on: nil)
                              )

      errors.add(:starts_on, :overlapping_delegation) if overlapping.exists?
    end
end
