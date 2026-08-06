# 利用者へ知らせる出来事。
#
# 文面は保存せず、表示するときに翻訳ファイルから組み立てる。
# 保存すると、利用者の表示言語を変えても過去の通知が変わらない。
#
# 二重に通知しない単位は「出来事の発生」とする。受け手と対象と種類だけで
# 一意にすると、差し戻したあとの再提出や、同じ利用者が担当する 2 つ目の段で、
# 新しい未読が作られない。届いたことに気付けないまま止まる。
#
# 発生を表す値は、同じ出来事に対して何度呼んでも同じものとする。時刻や
# 乱数を入れると、ジョブのやり直しで通知が増える。
class Notification < ApplicationRecord
  include WebhookPublishable

  EVENTS = %w[
    announcement_published
    event_invited
    request_submitted
    request_approved
    request_returned
  ].freeze

  # 発生を区別しない出来事に使う値。
  #
  # 公開や招待は、その対象について 1 度だけ起きる。区別する値を持たせても
  # 増える組み合わせが無く、持たせないほうが読み手に意図が伝わる。
  DEFAULT_OCCURRENCE = "".freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true

  validates :event, inclusion: { in: EVENTS }
  validates :occurrence, length: { maximum: 100 }
  belongs_to_same_organization :user, of: :subject

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  # 保持期間を過ぎた通知。期間を指定していない場合は 1 件も含まない。
  #
  # 境界の時刻ちょうどは含めない。指定した日数は「残す期間」であり、
  # その端は残す側に入る。監査記録と同じ数え方にする。
  scope :expired, ->(at: Time.current) do
    days = Officeweave::Configuration::NotificationRetention.days

    days ? where(created_at: ...(at - days.days)) : none
  end
  scope :unread, -> { where(read_at: nil) }

  # 未読だけへ絞るかどうか。指定が無ければ両方を返す。
  scope :with_read_state, ->(state) { unread if state == "unread" }

  # 同じ発生について二重に通知しない。
  # 通知を作る側は、重複を気にせず呼べるようにする。
  def self.deliver(user:, subject:, event:, occurrence: DEFAULT_OCCURRENCE)
    return nil if user.nil? || !user.active?

    notification = create!(user: user, subject: subject, event: event, occurrence: occurrence.to_s)
    notification.deliver_by_mail
    notification
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  # 複数の受け手へまとめて知らせる。作られた通知の識別子を返す。
  #
  # 1 件ずつ作らない。受け手の人数は組織の規模で決まるため、受け手ごとに
  # 問い合わせを出すと、組織全体へのお知らせ 1 件の公開が、そのまま
  # 利用者数に比例した待ち時間になる。公開は要求の中で行われる。
  #
  # 検証は書き込む前に全件へ行う。読み込み済みの利用者と対象を見るだけで
  # あり、問い合わせは出ない。1 件でも境界を越えていれば何も作らない。
  # 1 件ずつ作ると、ぶつかるまでの分だけが作られて残る。
  #
  # 重複は一意索引が弾く。読み飛ばした行は返らないため、実際に作られた
  # 通知だけがメールの対象になる。二重に通知しない契約は索引が担保する。
  def self.deliver_to_all(users:, subject:, event:, occurrence: DEFAULT_OCCURRENCE)
    recipients = users.to_a.select(&:active?)
    return [] if recipients.empty?

    ids = insert_notifications(rows_for(recipients, subject, event, occurrence.to_s))
    enqueue_mail_delivery(ids, event: event)
    ids
  end

  # 書き込む値を組み立てる。時刻は 1 つの基準から決める。
  # 受け手ごとに Time.current を呼ぶと、わずかにずれた並び順になる。
  def self.rows_for(recipients, subject, event, occurrence)
    now = Time.current

    recipients.map do |user|
      new(user: user, subject: subject, event: event, occurrence: occurrence).validate!

      { user_id: user.id, subject_type: subject.class.polymorphic_name, subject_id: subject.id,
        event: event, occurrence: occurrence, created_at: now, updated_at: now }
    end
  end
  private_class_method :rows_for

  def self.insert_notifications(rows)
    insert_all(rows, unique_by: %i[user_id subject_type subject_id event occurrence], returning: %w[id])
      .rows
      .flatten
  end
  private_class_method :insert_notifications

  # 受け手ごとの送信を要求の外へ出す。積むのは 1 件だけとし、人数のぶんだけ
  # キューへ書き込むことを避ける。
  #
  # 送信そのものは、これまでどおり通知 1 件につき 1 つのジョブが行う。
  # やり直しの単位は変えない。1 通の失敗が他の通知の送信を止めない。
  def self.enqueue_mail_delivery(ids, event:)
    return if ids.empty?

    JobEnqueue.perform("mail_fanout:#{event}") do
      NotificationMailFanoutJob.perform_later(ids)
    end
  end
  private_class_method :enqueue_mail_delivery

  # 出来事を外部の宛先へも送る。
  # 利用者ごとの通知とは独立して、組織につき 1 回だけ送る。
  def self.publish(organization:, subject:, event:, occurrence: DEFAULT_OCCURRENCE)
    publish_webhook(
      organization: organization,
      event: event,
      occurrence: occurrence.to_s,
      payload: { subject_type: subject.class.name, subject_id: subject.id, title: subject.try(:title).to_s }
    )
  end

  # 対象の件名。種類ごとに持つ属性が違うため、ここでそろえる。
  def subject_title
    subject.try(:title).to_s
  end

  # メールでも知らせる。
  # 送信の失敗で操作そのものが失敗しないよう、要求の外で処理する。
  # 画面での通知は設定に関わらず残す。設定はメールの受け取りだけを決める。
  def deliver_by_mail
    return unless user.mail_notifications_for?(event)

    JobEnqueue.perform("mail:#{event}") do
      NotificationMailer.with(notification: self).notify.deliver_later
    end
  end

  # 定期実行から呼ぶ。
  #
  # 通知は利用者ごとに増え続ける。読んだ通知も残るため、放っておくと
  # 一覧の問い合わせが重くなり、保管の対象も膨らむ。
  # 消した件数を返し、実行の記録から範囲を読み取れるようにする。
  def self.delete_expired(at: Time.current)
    expired(at: at).delete_all
  end

  def read?
    read_at.present?
  end

  def mark_as_read
    return if read?

    update!(read_at: Time.current)
  end
end
