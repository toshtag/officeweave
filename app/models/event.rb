# 予定。個人のものと、組織や部門で共有するものを同じ記録として扱う。
#
# 別々の記録に分けると、公開範囲を変えるたびに作り直すことになる。
class Event < ApplicationRecord
  VISIBILITIES = %w[private organization departments].freeze

  belongs_to :organization
  belongs_to :owner, class_name: "User"
  has_many :reservations, dependent: :nullify

  has_many :event_departments, dependent: :destroy
  has_many :departments, through: :event_departments

  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 10_000 }
  validates :starts_at, :ends_at, presence: true
  validates :visibility, inclusion: { in: VISIBILITIES }
  validate :ends_at_must_be_after_starts_at
  validate :departments_required_when_limited
  validate :departments_must_be_in_same_organization

  scope :starting_from, ->(time) { where(ends_at: time..) }
  scope :chronological, -> { order(:starts_at, :id) }

  # 利用者が見られる予定。
  # 自分の予定は公開範囲に関わらず見える。
  scope :visible_to, ->(user) {
    where(organization_id: user.organization_id)
      .where(
        arel_table[:owner_id].eq(user.id)
          .or(arel_table[:visibility].eq("organization"))
          .or(
            arel_table[:id].in(
              EventDepartment
                .where(department_id: Membership.where(user_id: user.id).select(:department_id))
                .select(:event_id).arel
            )
          )
      )
  }

  def limited_to_departments?
    visibility == "departments"
  end

  # 持ち主と管理者だけが変更できる。
  def editable_by?(user)
    owner_id == user.id || user.administrator?
  end

  private
    def ends_at_must_be_after_starts_at
      return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

      errors.add(:ends_at, :not_after_start)
    end

    def departments_required_when_limited
      return unless limited_to_departments?
      return if departments.any? || event_departments.any?

      errors.add(:department_ids, :blank)
    end

    def departments_must_be_in_same_organization
      return if departments.all? { |department| department.organization_id == organization_id }

      errors.add(:department_ids, :different_organization)
    end
end
