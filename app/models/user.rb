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

  # 新しく平文を割り当てた場合だけ、最低要件を確かめる。
  #
  # 保存済みの digest は対象にしない。要件を満たさないパスワードで既に運用して
  # いる利用者を、この検査だけでログインできなくすることはしない。
  # 経路ごとではなく User モデルへ置くことで、画面も CSV も初期データも同じ契約を通る。
  validate :password_meets_policy, if: :password_assigned?

  scope :ordered, -> { order(:name) }
  scope :active, -> { where(deactivated_at: nil) }
  scope :deactivated, -> { where.not(deactivated_at: nil) }

  # 組織には利用中の管理者が少なくとも 1 人必要とする。
  # 管理者が誰もいなくなると、利用者も部門も設定も画面からは戻せない。
  #
  # 判定は保存の直前に 1 か所だけ置く。画面、無効化、CSV 取込へ個別に
  # 置くと、経路が増えたときに漏れる。
  before_update :preserve_active_administrator, if: :removing_active_administrator?

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

  private
    # 空欄での送信は「変更しない」を意味する。未入力を要件の違反にしない。
    # 値そのものの必須は has_secure_password が確かめる。
    def password_assigned?
      !password.nil? && !password.empty?
    end

    def password_meets_policy
      case Authentication::PasswordPolicy.violation(password)
      when :blank
        errors.add(:password, :blank)
      when :known_unsafe
        errors.add(:password, :known_unsafe)
      when :too_short
        errors.add(:password, :too_short, count: Authentication::PasswordPolicy::MINIMUM_LENGTH)
      end
    end

    # 保存前は利用中の管理者で、保存後はそうでなくなる更新だけを対象とする。
    # 一般利用者の更新や、管理者への昇格、管理者の氏名変更は対象にしない。
    def removing_active_administrator?
      active_administrator_in_database? && !(administrator? && active?)
    end

    def active_administrator_in_database?
      attribute_in_database("role") == "administrator" &&
        attribute_in_database("deactivated_at").nil?
    end

    # 件数を数えるだけでは、同時に実行された 2 件の降格が互いを管理者として
    # 観測し、両方成功しうる。組織の行を占有してから数え直すことで、
    # 判定と更新を組織単位で直列化する。ロックは更新のトランザクションが
    # 終わるまで保持される。
    def preserve_active_administrator
      Organization.lock.find(organization_id)

      return if another_active_administrator_exists?

      errors.add(:base, :last_active_administrator)
      throw(:abort)
    end

    # 読み込み済みの関連ではなく、ロック後のデータベースへ問い合わせる。
    def another_active_administrator_exists?
      User.where(organization_id: organization_id)
          .active
          .administrator
          .where.not(id: id)
          .exists?
    end
end
