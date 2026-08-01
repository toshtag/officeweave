# 利用者へ知らせる出来事。
#
# 文面は保存せず、表示するときに翻訳ファイルから組み立てる。
# 保存すると、利用者の表示言語を変えても過去の通知が変わらない。
class Notification < ApplicationRecord
  include WebhookPublishable

  EVENTS = %w[
    announcement_published
    request_submitted
    request_approved
    request_returned
  ].freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true

  validates :event, inclusion: { in: EVENTS }
  belongs_to_same_organization :user, of: :subject

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :unread, -> { where(read_at: nil) }

  # 同じ出来事について二重に通知しない。
  # 通知を作る側は、重複を気にせず呼べるようにする。
  def self.deliver(user:, subject:, event:)
    return nil if user.nil? || !user.active?

    notification = create!(user: user, subject: subject, event: event)
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
  def self.deliver_to_all(users:, subject:, event:)
    recipients = users.to_a.select(&:active?)
    return [] if recipients.empty?

    ids = insert_notifications(rows_for(recipients, subject, event))
    enqueue_mail_delivery(ids, event: event)
    ids
  end

  # 書き込む値を組み立てる。時刻は 1 つの基準から決める。
  # 受け手ごとに Time.current を呼ぶと、わずかにずれた並び順になる。
  def self.rows_for(recipients, subject, event)
    now = Time.current

    recipients.map do |user|
      new(user: user, subject: subject, event: event).validate!

      { user_id: user.id, subject_type: subject.class.polymorphic_name, subject_id: subject.id,
        event: event, created_at: now, updated_at: now }
    end
  end
  private_class_method :rows_for

  def self.insert_notifications(rows)
    insert_all(rows, unique_by: %i[user_id subject_type subject_id event], returning: %w[id])
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
  def self.publish(organization:, subject:, event:)
    publish_webhook(
      organization: organization,
      event: event,
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

  def read?
    read_at.present?
  end

  def mark_as_read
    return if read?

    update!(read_at: Time.current)
  end
end
