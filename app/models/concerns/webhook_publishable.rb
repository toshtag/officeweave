# 出来事を Webhook の宛先へ送る。
#
# 送信の呼び出しを 1 か所にまとめる。
# 出来事ごとに書くと、宛先の絞り込みや送信内容の形が食い違う。
#
# 配送は at-least-once とする。相手が受理した直後に接続が切れた場合、
# 同じ本文が二度届くことがある。届いたことを確かめる手段がないため、
# 届かないより届きすぎる側へ倒す。受け取る側は、本文の `event` と
# `occurrence` の組で重複を捨てられる。
module WebhookPublishable
  extend ActiveSupport::Concern

  class_methods do
    def publish_webhook(organization:, event:, payload:, occurrence: "")
      return unless WebhookEndpoint::EVENTS.include?(event)

      # 時刻は宛先ごとに取り直さない。同じ発生が、宛先によって違う時刻で
      # 届くと、受け取る側が並べ直せない。
      occurred_at = Time.current

      organization.webhook_endpoints.active.find_each do |endpoint|
        JobEnqueue.perform("webhook:#{event}") do
          DeliverWebhookJob.perform_later(
            endpoint.id,
            event,
            WebhookPayload.build(event: event, occurrence: occurrence,
                                 occurred_at: occurred_at, attributes: payload)
          )
        end
      end
    end
  end
end
