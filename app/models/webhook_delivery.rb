# Webhook の送信結果。
#
# 届いているかを運用時に確認できるようにする。
# 記録がないと、送っていないのか届かなかったのかを区別できない。
class WebhookDelivery < ApplicationRecord
  belongs_to :webhook_endpoint

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  def succeeded?
    response_status.present? && response_status.between?(200, 299)
  end
end
