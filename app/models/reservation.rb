# 設備・備品の予約。
#
# 同じ設備・備品の時間帯が重ならないことは、データベース側の制約で保証する。
# 模型側の確認だけでは、同時に申し込まれた場合に両方が通ってしまう。
class Reservation < ApplicationRecord
  belongs_to :organization
  belongs_to :resource
  belongs_to :reserver, class_name: "User"
  belongs_to :event, optional: true

  validates :starts_at, :ends_at, presence: true
  validates :purpose, length: { maximum: 200 }
  validate :ends_at_must_be_after_starts_at
  validate :resource_must_be_reservable
  belongs_to_same_organization :resource, :reserver, :event
  validate :must_not_overlap_existing_reservation

  scope :chronological, -> { order(:starts_at, :id) }
  scope :starting_from, ->(time) { where(ends_at: time..) }
  # 終端を含まない範囲として重なりを判定する。
  # 直前の終了時刻と次の開始時刻が同じ場合は重ならない扱いにする。
  # データベース側の制約と同じ判定にそろえる。
  scope :overlapping, ->(starts_at, ends_at) {
    where(arel_table[:starts_at].lt(ends_at)).where(arel_table[:ends_at].gt(starts_at))
  }

  # 持ち主と管理者だけが取り消せる。
  def cancelable_by?(user)
    reserver_id == user.id || user.administrator?
  end

  # データベースの制約に触れた場合も、画面へ理由を返せるようにする。
  def save_with_overlap_check
    save
  rescue ActiveRecord::StatementInvalid => error
    raise unless error.message.include?("reservations_must_not_overlap")

    errors.add(:base, :overlapping)
    false
  end

  private
    def ends_at_must_be_after_starts_at
      return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

      errors.add(:ends_at, :not_after_start)
    end

    def resource_must_be_reservable
      return if resource.nil? || resource.reservable?

      errors.add(:resource, :not_reservable)
    end

    def must_not_overlap_existing_reservation
      return if resource_id.blank? || starts_at.blank? || ends_at.blank? || ends_at <= starts_at

      conflicting = Reservation.where(resource_id: resource_id).overlapping(starts_at, ends_at)
      conflicting = conflicting.where.not(id: id) if persisted?

      errors.add(:base, :overlapping) if conflicting.exists?
    end
end
