# 出来事を外部へ送る宛先。
#
# 宛先は管理者が登録する。ただし、登録できる利用者を絞ることだけを防御にしない。
# 誤った登録も、権限を奪われた場合も、内部ネットワークへの入口になり得る。
# 宛先として妥当かどうかは WebhookDestination が判断する。
class WebhookEndpoint < ApplicationRecord
  # 送る出来事。通知と同じ区分にそろえる。
  EVENTS = Notification::EVENTS

  belongs_to :organization

  has_many :webhook_deliveries, dependent: :destroy

  validates :name, presence: true, length: { maximum: 100 }
  validates :url, presence: true, length: { maximum: 2_000 }
  validate :url_must_be_permitted_destination, if: :destination_check_required?
  validates :secret, presence: true, length: { maximum: 200 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name, :id) }

  before_validation :assign_secret, on: :create

  # 送信内容の署名。受け取る側が同じ計算で検証できる。
  def signature_for(payload)
    OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
  end

  private
    # 名前解決を伴う検査は、宛先か有効状態が変わるときだけ行う。
    # 名前の変更などで毎回行うと、DNS の一時的な不調で無関係な更新まで止まる。
    def destination_check_required?
      return false if url.blank?

      new_record? || url_changed? || (active_changed? && active?)
    end

    # 保存の時点で誤りを管理者へ返す。
    # ただし、これを唯一の防御にしない。送信の時点でも同じ検査を行う。
    def url_must_be_permitted_destination
      WebhookDestination.resolve!(url)
    rescue WebhookDestination::Error => error
      errors.add(:url, error.reason)
    end

    def assign_secret
      self.secret = SecureRandom.hex(32) if secret.blank?
    end
end
