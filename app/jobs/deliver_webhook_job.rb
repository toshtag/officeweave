require "net/http"

# 出来事を宛先へ送る。
#
# 送信は要求の外で行う。宛先が応答しない場合に、
# 画面の操作がその待ち時間だけ止まらないようにする。
class DeliverWebhookJob < ApplicationJob
  queue_as :default

  # 宛先が応答しない場合に、いつまでも待たない。
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  def perform(webhook_endpoint_id, event, payload)
    endpoint = WebhookEndpoint.active.find_by(id: webhook_endpoint_id)
    return if endpoint.nil?

    body = payload.to_json
    delivery = endpoint.webhook_deliveries.new(event: event)

    begin
      response = post(endpoint, body)
      delivery.response_status = response.code.to_i
      delivery.delivered_at = Time.current
    rescue StandardError => error
      # 宛先の不調で送信元が落ちないようにする。結果だけを記録する。
      delivery.error_message = error.message.truncate(200)
    end

    delivery.save!
  end

  private
    def post(endpoint, body)
      uri = URI.parse(endpoint.url)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-OfficeWeave-Signature"] = endpoint.signature_for(body)
      request.body = body

      Net::HTTP.start(uri.hostname, uri.port,
                      use_ssl: uri.scheme == "https",
                      open_timeout: OPEN_TIMEOUT,
                      read_timeout: READ_TIMEOUT) do |http|
        http.request(request)
      end
    end
end
