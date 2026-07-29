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

  scope :active, -> { where(revoked_at: nil) }
  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  before_validation :assign_token, on: :create

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
    def assign_token
      @token = SecureRandom.urlsafe_base64(32)
      self.token_digest = self.class.digest(@token)
    end
end
