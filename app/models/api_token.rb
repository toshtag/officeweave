# 外部からの接続に使う token。
#
# 値そのものは保存せず、要約だけを持つ。
# 保存すると、記録が漏れた時点ですべての接続が使えてしまう。
#
# 権限は発行した利用者から引き継ぐ。
# token に独自の権限を持たせると、利用者の権限を変えても接続だけが残る。
class ApiToken < ApplicationRecord
  belongs_to :organization
  belongs_to :user

  # 発行時にだけ参照できる値。
  attr_reader :token

  validates :name, presence: true, length: { maximum: 100 }
  belongs_to_same_organization :user

  scope :active, -> { where(revoked_at: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  before_validation :assign_token, on: :create
  before_create :require_active_user

  # 送られてきた値から、使える token を探す。
  # 無効にされた利用者の token は使えない。
  def self.authenticate(value)
    return nil if value.blank?

    token = active.find_by(token_digest: digest(value))
    return nil if token.nil? || !token.user.active?

    token.touch(:last_used_at)
    token
  end

  def self.digest(value)
    Digest::SHA256.hexdigest(value)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  private
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
