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
  belongs_to_same_organization :resource, :reserver
  validate :event_must_be_visible_to_reserver
  validate :must_not_overlap_existing_reservation

  scope :chronological, -> { order(:starts_at, :id) }
  scope :starting_from, ->(time) { where(ends_at: time..) }
  # 終端を含まない範囲として重なりを判定する。
  # 直前の終了時刻と次の開始時刻が同じ場合は重ならない扱いにする。
  # データベース側の制約と同じ判定にそろえる。
  scope :overlapping, ->(starts_at, ends_at) {
    where(arel_table[:starts_at].lt(ends_at)).where(arel_table[:ends_at].gt(starts_at))
  }

  # 持ち主と管理者だけが変更と取り消しをできる。
  #
  # 変更と取り消しで範囲を分けない。分けると、取り消して作り直せる利用者が
  # 変更だけはできない状態になる。結果として同じことができる。
  def modifiable_by?(user)
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

  def update_with_overlap_check(attributes)
    assign_attributes(attributes)

    save_with_overlap_check
  end

  private
    # 結び付けられる予定を、予約する利用者が参照できるものに限る。
    #
    # 画面は参照できる予定だけを選択肢に並べるが、受け入れ側に同じ判定が
    # ないと、選択肢に無い識別子をそのまま送れる。判定は模型へ置く。
    # 画面へ置くと、予約を作る経路が増えたときに漏れる。
    #
    # 組織の一致は Event.visible_to が予約者の組織で絞ることで満たされる。
    # 予約者が予約と同じ組織にいることは belongs_to_same_organization が
    # 確かめるため、belongs_to_same_organization からは :event を外した。
    # 同じ関連へ 2 つの検証を並べると、別組織の予定だけ誤りが 2 件になり、
    # 内容の違いから所属組織を判別できてしまう。
    #
    # 存在しない識別子もここで拒む。optional な関連は模型の検証では
    # 拒まれず、そのまま外部キー検査へ届いて応答が壊れる。
    #
    # 予約者が決まらない場合は何も言わない。予約者そのものの検証が扱う。
    #
    # 予定の日時は見ない。画面の選択肢は今より後のものに絞っているが、
    # それは選びやすさのためであり、参照できる範囲の判断ではない。
    def event_must_be_visible_to_reserver
      return if event_id.blank? || reserver.nil?
      return if Event.visible_to(reserver).exists?(id: event_id)

      errors.add(:event, :not_visible)
    end

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
