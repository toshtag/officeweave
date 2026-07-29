# 申請。提出、承認、差し戻し、取り下げの状態を持つ。
#
# 状態はひとつの列で表す。複数の真偽値で表すと、
# 承認済みかつ差し戻し済みのような、あり得ない組み合わせを作れてしまう。
class Request < ApplicationRecord
  STATUSES = %w[draft pending approved returned withdrawn].freeze

  # 各状態から移れる先。ここにない移動は受け付けない。
  ALLOWED_TRANSITIONS = {
    "draft" => %w[pending withdrawn],
    "pending" => %w[approved returned withdrawn],
    "returned" => %w[pending withdrawn],
    "approved" => [],
    "withdrawn" => []
  }.freeze

  belongs_to :organization
  belongs_to :request_type
  belongs_to :applicant, class_name: "User"

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 10_000 }
  validates :status, inclusion: { in: STATUSES }
  validate :request_type_must_be_in_same_organization
  validate :request_type_must_be_active, on: :create

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :with_status, ->(status) { where(status: status) if status.in?(STATUSES) }

  # 申請者本人と、承認できる利用者だけが参照できる。
  scope :visible_to, ->(user) {
    where(organization_id: user.organization_id)
      .where(
        arel_table[:applicant_id].eq(user.id).or(
          arel_table[:request_type_id].in(approvable_request_type_ids(user))
        )
      )
  }

  def self.approvable_request_type_ids(user)
    return RequestType.where(organization_id: user.organization_id).select(:id).arel if user.administrator?

    RequestType
      .where(approver_department_id: Membership.where(user_id: user.id).select(:department_id))
      .select(:id).arel
  end

  def can_transition_to?(next_status)
    ALLOWED_TRANSITIONS.fetch(status, []).include?(next_status)
  end

  def editable_by?(user)
    applicant_id == user.id && status.in?(%w[draft returned])
  end

  def withdrawable_by?(user)
    applicant_id == user.id && can_transition_to?("withdrawn")
  end

  def submit
    return false unless can_transition_to?("pending")

    update(status: "pending", submitted_at: Time.current)
  end

  def withdraw
    return false unless can_transition_to?("withdrawn")

    update(status: "withdrawn")
  end

  private
    def request_type_must_be_in_same_organization
      return if request_type.nil? || request_type.organization_id == organization_id

      errors.add(:request_type, :different_organization)
    end

    def request_type_must_be_active
      return if request_type.nil? || request_type.active?

      errors.add(:request_type, :not_active)
    end
end
