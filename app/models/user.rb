class User < ApplicationRecord
  has_secure_password

  belongs_to :organization
  has_many :sessions, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :departments, through: :memberships

  # 主たる所属。連絡先の表示や既定の絞り込みに使う。
  #
  # 関連として宣言する。読み込み済みの memberships を絞り込む形にすると、
  # 絞り込みが新しい関連を作るため、先読みした配列が使われない。一覧は
  # 行ごとに主たる所属を表示するため、利用者の人数だけ問い合わせが増える。
  #
  # 利用者につき 1 件までであることは、部分一意索引
  # index_memberships_on_primary_user が保証している。
  has_one :primary_membership, -> { primary }, class_name: "Membership", inverse_of: :user,
          dependent: nil
  has_one :primary_department, through: :primary_membership, source: :department
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

  # パスワードが変わったら、その利用者の進行中のセッションを終わらせる。
  #
  # パスワードの変更は、資格情報が漏れた疑いに対する最初の対処である。
  # 変えるだけでは、漏れた資格情報で既に開始された接続は終わらない。
  # セッションの期限は時間の経過だけで来るため、無操作でも 30 分、
  # 使い続けていれば最長 8 時間そのまま残る。
  #
  # 判定は保存後の digest の変化で行う。経路ごとに置くと、パスワードを
  # 設定できる経路が増えたときに漏れる。検証ではなくコールバックへ置く
  # ことで、検証を省いた保存も同じ契約を通る。
  #
  # 保存と同じトランザクションで確定する。保存だけが残ると、変えたはずの
  # 資格情報で接続が続く。
  after_update :discard_sessions, if: :saved_change_to_password_digest?

  def active?
    deactivated_at.nil?
  end

  # 利用を止める。記録は残したまま、ログインと新たな割り当てを止める。
  # 進行中のセッションと発行済みの token もここで終わらせる。
  #
  # ログインの経路だけを止めても、外部からの接続は残る。
  # 認証のたびに利用者の状態を見るだけでは、再び有効にした時点で
  # 無効化前の token がそのまま使えるようになる。
  #
  # 3 つを同じトランザクションで確定する。どれか 1 つでも失敗した場合に
  # 無効化だけが残ると、止めたはずの経路が開いたままになる。
  def deactivate!
    transaction do
      at = Time.current

      update!(deactivated_at: at)
      sessions.destroy_all
      revoke_api_tokens(at: at)
    end
  end

  def activate!
    update!(deactivated_at: nil)
  end

  # その種類の通知をメールでも受け取るか。
  # 設定していない種類は受け取る扱いとする。
  #
  # 読み込み済みの配列から選ぶ。`find_by` は関連が先読み済みでも問い合わせを
  # 出すため、まとめて配信する経路では受け手の人数だけ往復が増える。
  # 設定の種類は Notification::EVENTS の数までであり、全件読んでも増えない。
  def mail_notifications_for?(event)
    preference = notification_preferences.detect { |candidate| candidate.event == event }

    preference.nil? || preference.mail_enabled?
  end

  private
    # API token はここでは失効させない。
    #
    # token はパスワードから導かれる資格情報ではなく、利用者が用途ごとに
    # 発行し、画面から個別に失効できる。定期的なパスワードの変更で
    # まとめて失効させると、外部との接続がその都度切れる。
    #
    # 無効化が token も失効させるのは、利用そのものを止める操作だからである。
    # パスワードの変更は利用を止めない。両者を同じ扱いにしない。
    def discard_sessions
      sessions.destroy_all
    end

    # 有効な token だけを対象にする。すでに失効している token の時刻を
    # 書き換えると、いつ使えなくなったのかが分からなくなる。
    #
    # 1 件ずつ revoke! を呼ぶと、token の件数だけ UPDATE が増える。
    # 失効の時刻はすべて同じであり、1 文で足りる。
    def revoke_api_tokens(at:)
      api_tokens.active.update_all(revoked_at: at, updated_at: at)
    end

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
