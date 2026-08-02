# 外部からの接続に使う token。
#
# 値そのものは保存せず、要約だけを持つ。
# 保存すると、記録が漏れた時点ですべての接続が使えてしまう。
#
# 権限は発行した利用者から引き継ぐ。
# token に独自の権限を持たせると、利用者の権限を変えても接続だけが残る。
#
# 範囲（scopes）は、引き継いだ権限を狭めるだけとする。広げない。
# 利用者の一覧のように、管理者だけが読めるものは、範囲を許しても読めない。
class ApiToken < ApplicationRecord
  include ActivityRecording

  # 最終利用時刻を書き込む間隔。
  #
  # この時刻は利用の記録であり、認証の判定には使わない。要求ごとに書くと、
  # 外部からの接続の回数だけ書き込みが起きる。
  USE_WRITE_INTERVAL = 1.minute

  # 発行のときに選べる期限。日数で示す。
  #
  # 任意の日数を受け取らない。受け取ると、1 日や 10 年といった値が画面から
  # 入る。用途が終わったあとに残る時間の長さを、この 3 つに絞る。
  EXPIRY_CHOICES = [ 30, 90, 365 ].freeze

  # 期限を選ばなかった場合に使う日数。
  #
  # 期限なしを既定にすると、期限を選べることに気付かないまま発行される。
  DEFAULT_EXPIRY_DAYS = 90

  # 許可できる範囲。API の資源に対応する。
  #
  # 資源より細かくしない（読み取りと書き込みを分けるなど）。今の API は
  # 読み取りだけであり、分けても選ぶ側に判断の材料が無い。
  SCOPES = %w[announcements events departments users].freeze

  belongs_to :organization
  belongs_to :user

  # 発行時にだけ参照できる値。
  attr_reader :token

  # 選んだ順や重複で、同じ範囲の token が別の値として残らないようにする。
  # 指定が無い（nil）ことは「すべて」を表す。空の配列とは区別する。
  normalizes :scopes, with: lambda { |value|
    value.compact_blank.uniq.sort_by { |scope| SCOPES.index(scope) || SCOPES.size }
  }

  validates :name, presence: true, length: { maximum: 100 }
  validates :scopes, presence: true, allow_nil: true
  validate :scopes_are_known, if: -> { scopes.present? }
  # 過去の期限で発行させない。発行した時点で使えない token ができる。
  validate :expires_in_future, if: -> { expires_at.present? && will_save_change_to_expires_at? }
  belongs_to_same_organization :user

  scope :active, -> { where(revoked_at: nil) }

  # まだ使える token。失効しておらず、期限も過ぎていないもの。
  #
  # 期限を持たない token は含める。既に発行した token の使える範囲を
  # 後から狭めない。
  scope :usable, ->(at: Time.current) do
    active.where(expires_at: nil).or(active.where(arel_table[:expires_at].gt(at)))
  end

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  before_validation :assign_token, on: :create
  before_create :require_active_user

  # 送られてきた値から、使える token を探す。
  # 失効した token、期限を過ぎた token、無効にされた利用者の token は使えない。
  # 利用者は同じ問い合わせで読む。別の問い合わせにすると、外部からの接続
  # 1 回につき往復が 1 つ増える。
  def self.authenticate(value)
    return nil if value.blank?

    token = usable.eager_load(:user).find_by(token_digest: digest(value))
    return nil if token.nil? || !token.user.active?

    token.record_use!
    token
  end

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end

  # 直前に記録していれば書かない。いつ頃まで使われていたかが分かればよく、
  # 1 分より細かい精度は要らない。
  def record_use!(at: Time.current)
    return if recorded_recently?(last_used_at, at, USE_WRITE_INTERVAL)

    touch(:last_used_at, time: at)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  # 期限を過ぎている。失効とは分ける。
  # 失効は人が止めたことであり、期限は発行のときに決めた条件である。
  def expired?(at: Time.current)
    expires_at.present? && expires_at <= at
  end

  def usable?(at: Time.current)
    !revoked? && !expired?(at: at)
  end

  # その範囲を読めるか。
  #
  # 指定が無い token はすべてを許す。範囲の一覧を後から増やしたときも、
  # 既に発行した token の使える範囲を狭めない。
  def permits?(scope)
    scopes.nil? || scopes.include?(scope.to_s)
  end

  private
    def scopes_are_known
      unknown = scopes - SCOPES

      errors.add(:scopes, :not_a_choice) if unknown.any?
    end

    def expires_in_future
      errors.add(:expires_at, :not_in_future) if expires_at <= Time.current
    end

    # 発行の直前に、データベース上の利用者を占有して確かめる。
    #
    # 画面や読み込み済みの関連で確かめても、確かめてから INSERT するまでの
    # 間に無効化が成立し得る。占有はこの保存のトランザクションが終わるまで
    # 保持されるため、無効化側の利用者の更新は INSERT の完了まで待つ。
    # 逆に無効化が先に成立していれば、ここで無効な状態を読み取って拒む。
    #
    # 組織の行を先に取る。api_tokens の INSERT は organization_id の
    # 外部キー検査で組織の行を KEY SHARE で参照するため、明示しなければ
    # 利用者 → 組織の順に取ることになる。最後の管理者を守る更新は
    # 組織 → 利用者の順に取るため、管理者の無効化と発行が同時に走ると
    # 互いの相手を待つ循環になり、どちらかが Deadlocked で中断される。
    def require_active_user
      return if lock_issuance_target.active?

      errors.add(:user, :inactive)
      throw(:abort)
    end

    # 組織へ FOR UPDATE は使わない。同じ組織の発行同士まで直列になる。
    # 外部キー検査と同じ KEY SHARE を先に取れば、組織の行を FOR UPDATE で
    # 占有する管理者の無効化とだけ競合し、発行同士は並行できる。
    def lock_issuance_target
      Organization.lock("FOR KEY SHARE").find(organization_id)
      User.lock.find(user_id)
    end

    def assign_token
      @token = SecureRandom.urlsafe_base64(32)
      self.token_digest = self.class.digest(@token)
    end
end
