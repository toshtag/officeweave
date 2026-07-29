class User < ApplicationRecord
  has_secure_password

  belongs_to :organization
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :departments, through: :memberships
  has_many :announcements, foreign_key: :author_id, dependent: :restrict_with_error, inverse_of: :author
  has_many :announcement_reads, dependent: :destroy
  has_many :events, foreign_key: :owner_id, dependent: :restrict_with_error, inverse_of: :owner
  has_many :reservations, foreign_key: :reserver_id, dependent: :restrict_with_error, inverse_of: :reserver
  has_many :requests, foreign_key: :applicant_id, dependent: :restrict_with_error, inverse_of: :applicant
  has_many :request_activities, foreign_key: :actor_id, dependent: :restrict_with_error, inverse_of: :actor
  has_many :documents, foreign_key: :author_id, dependent: :restrict_with_error, inverse_of: :author
  has_many :notifications, dependent: :destroy
  has_many :notification_preferences, dependent: :destroy
  has_many :api_tokens, dependent: :destroy

  # 大文字小文字と前後の空白の違いで別の利用者として扱わない。
  # 権限は 2 段階だけとする。
  # 役割を細かく分けるのは、実際に区別が必要な操作が現れてからにする。
  enum :role, { member: "member", administrator: "administrator" }, validate: true

  normalizes :email_address, with: ->(value) { value.strip.downcase }
  # 画面の「設定しない」は空文字で送られる。未設定として扱う。
  normalizes :locale, with: ->(value) { value.presence }

  validates :name, presence: true, length: { maximum: 100 }
  validates :email_address, presence: true, length: { maximum: 255 },
                            format: { with: URI::MailTo::EMAIL_REGEXP }

  # 表示言語の設定。未設定の場合は要求ごとの判定に従う。
  validates :locale, inclusion: { in: ->(_) { I18n.available_locales.map(&:to_s) } },
                     allow_nil: true

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(deactivated_at: nil) }
  scope :deactivated, -> { where.not(deactivated_at: nil) }

  def active?
    deactivated_at.nil?
  end

  # 利用を止める。記録は残したまま、ログインと新たな割り当てを止める。
  # 進行中のセッションもここで終わらせる。
  def deactivate!
    transaction do
      update!(deactivated_at: Time.current)
      sessions.destroy_all
    end
  end

  def activate!
    update!(deactivated_at: nil)
  end

  # その種類の通知をメールでも受け取るか。
  # 設定していない種類は受け取る扱いとする。
  def mail_notifications_for?(event)
    preference = notification_preferences.find_by(event: event)

    preference.nil? || preference.mail_enabled?
  end

  # 主たる所属。連絡先の表示や既定の絞り込みに使う。
  def primary_department
    memberships.primary.first&.department
  end
end
