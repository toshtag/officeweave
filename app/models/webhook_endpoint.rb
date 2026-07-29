# 出来事を外部へ送る宛先。
#
# 宛先は管理者が登録する。任意の URL へ送るため、
# 登録できる利用者を管理者に限ることが唯一の防御になる。
class WebhookEndpoint < ApplicationRecord
  # 送る出来事。通知と同じ区分にそろえる。
  EVENTS = Notification::EVENTS

  belongs_to :organization

  has_many :webhook_deliveries, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :url, presence: true, length: { maximum: 2_000 }
  validate :url_must_be_http
  validates :secret, presence: true, length: { maximum: 200 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }

  before_validation :assign_secret, on: :create

  # 送信内容の署名。受け取る側が同じ計算で検証できる。
  def signature_for(payload)
    OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
  end

  private
    # 形式の判定を正規表現で行うと、改行を挟んだ値が通り抜ける。
    # 実際に解析して、方式と宛先が揃っていることを確かめる。
    def url_must_be_http
      return if url.blank?

      uri = URI.parse(url)

      errors.add(:url, :invalid) unless uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      errors.add(:url, :invalid)
    end

    def assign_secret
      self.secret = SecureRandom.hex(32) if secret.blank?
    end
end
