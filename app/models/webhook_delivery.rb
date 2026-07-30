# Webhook の送信結果。
#
# 届いているかを運用時に確認できるようにする。
# 記録がないと、送っていないのか届かなかったのかを区別できない。
#
# 宛先の検査で拒否した場合は failure_code に理由の符号を残す。
# 通信そのものの誤りは error_message に残す。
# どちらにも内部の IP アドレスや名前解決の結果を入れない。
class WebhookDelivery < ApplicationRecord
  belongs_to :webhook_endpoint

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def succeeded?
    response_status.present? && response_status.between?(200, 299)
  end

  def rejected?
    failure_code.present?
  end

  # 画面へ出す結果。
  # 応答があればその状態、拒否なら理由、それ以外は通信の誤り。
  def outcome
    return response_status.to_s if response_status.present?
    return I18n.t("webhook_endpoints.failures.#{failure_code}", default: failure_code) if rejected?

    error_message
  end
end
