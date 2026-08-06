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

  # 指名した参加者。公開範囲とは別に、見られる相手を増やす。
  has_many :event_participants, dependent: :destroy
  has_many :participants, through: :event_participants, source: :user

  # 同じ繰り返しの回。最初の回も自分の識別子を持つ。
  belongs_to :series, class_name: "Event", optional: true
  has_many :series_events, class_name: "Event", foreign_key: :series_id,
           dependent: nil, inverse_of: :series

  validates :title, presence: true, length: { maximum: 200 }
  validates :description, length: { maximum: 10_000 }
  validates :starts_at, :ends_at, presence: true
  validates :visibility, inclusion: { in: VISIBILITIES }
  belongs_to_same_organization :owner
  validate :ends_at_must_be_after_starts_at
  validate :departments_required_when_limited
  validate :departments_must_be_in_same_organization

  scope :starting_from, ->(time) { where(ends_at: time..) }

  # 繰り返しの一部かどうか。
  def recurring? = series_id.present?

  # この回と、これより後の回をまとめて消す。
  #
  # 前の回は消さない。既に終わった回を、後からの操作で消さない。
  def destroy_following
    return destroy unless recurring?

    Event.where(series_id: series_id).where(starts_at: starts_at..).destroy_all
  end

  # 参加者を指名し直す。新しく指名した相手だけへ知らせる。
  #
  # 既に参加者である利用者へ重ねて知らせない。予定を直すたびに同じ知らせが
  # 届くことになる。外した相手へも知らせない。
  def invite(users:, actor:)
    added = nil

    transaction do
      existing = participants.to_a
      self.participants = users.reject { |user| user.id == owner_id }
      added = participants.reload.to_a - existing
    end

    return added if added.empty?

    Notification.deliver_to_all(users: added.reject { |user| user.id == actor.id },
                                subject: self, event: "event_invited")
    # 外部の宛先へも送る。一覧に挙げた出来事のうち、これだけが送る経路を
    # 持っていなかった。挙げただけで送られない出来事は、宛先を登録した側から
    # 見て、届かない理由が分からない。
    Notification.publish(organization: organization, subject: self, event: "event_invited")
    added
  end
  scope :chronological, -> { order(:starts_at, :id) }
  # 期間の終わりで区切る。始まりだけで絞ると、蓄積した記録がそのまま
  # 読み込む量になる。終わりの日を含む。
  scope :starting_before, ->(time) { where(arel_table[:starts_at].lt(time)) }

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
          .or(
            # 指名された参加者は、公開範囲に関わらず見られる。
            arel_table[:id].in(EventParticipant.where(user_id: user.id).select(:event_id).arel)
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
