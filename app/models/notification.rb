# 利用者へ知らせる出来事。
#
# 文面は保存せず、表示するときに翻訳ファイルから組み立てる。
# 保存すると、利用者の表示言語を変えても過去の通知が変わらない。
class Notification < ApplicationRecord
  EVENTS = %w[
    announcement_published
    request_submitted
    request_approved
    request_returned
  ].freeze

  belongs_to :user
  belongs_to :subject, polymorphic: true

  validates :event, inclusion: { in: EVENTS }

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

  def self.deliver_to_all(users:, subject:, event:)
    users.each { |user| deliver(user: user, subject: subject, event: event) }
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

    NotificationMailer.with(notification: self).notify.deliver_later
  end

  def read?
    read_at.present?
  end

  def mark_as_read
    return if read?

    update!(read_at: Time.current)
  end
end
