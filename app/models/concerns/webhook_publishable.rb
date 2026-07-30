# 出来事を Webhook の宛先へ送る。
#
# 送信の呼び出しを 1 か所にまとめる。
# 出来事ごとに書くと、宛先の絞り込みや送信内容の形が食い違う。
module WebhookPublishable
  extend ActiveSupport::Concern

  class_methods do
    def publish_webhook(organization:, event:, payload:)
      return unless WebhookEndpoint::EVENTS.include?(event)

      organization.webhook_endpoints.active.find_each do |endpoint|
        JobEnqueue.perform("webhook:#{event}") do
          DeliverWebhookJob.perform_later(
            endpoint.id,
            event,
            { event: event, occurred_at: Time.current.iso8601 }.merge(payload)
          )
        end
      end
    end
  end
end
