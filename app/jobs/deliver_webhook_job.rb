require "net/http"

# 出来事を宛先へ送る。
#
# 送信は要求の外で行う。宛先が応答しない場合に、
# 画面の操作がその待ち時間だけ止まらないようにする。
#
# 宛先の検査は保存時にも行うが、それだけでは足りない。
# 保存後に名前解決の結果が内部のアドレスへ変わると、保存時の検査は通り抜ける。
# そのため送信のたびに解決し直し、接続先をその結果へ固定する。
class DeliverWebhookJob < ApplicationJob
  queue_as :default

  # 宛先が応答しない場合に、いつまでも待たない。
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  WRITE_TIMEOUT = 10

  # 名前解決と許可リストは、テストから差し替える。
  # インスタンスの中に閉じ、他のテストへ漏れる状態を作らない。
  attr_writer :resolver, :allowlist

  def perform(webhook_endpoint_id, event, payload)
    endpoint = WebhookEndpoint.active.find_by(id: webhook_endpoint_id)
    return if endpoint.nil?

    delivery = endpoint.webhook_deliveries.new(event: event)
    destination = resolve(endpoint.url)

    if destination.nil?
      # 拒否した場合も記録を残す。記録がないと、送っていないのか届かなかったのか分からない。
      delivery.failure_code = @failure_code
      delivery.save!
      return
    end

    deliver(endpoint, destination, delivery, payload)
  end

  private
    def resolver
      @resolver || WebhookDestination::DEFAULT_RESOLVER
    end

    def resolve(url)
      WebhookDestination.resolve!(url, resolver: resolver, allowlist: @allowlist)
    rescue WebhookDestination::Error => error
      # 理由の符号だけを残す。解決した IP は記録にも記録簿にも出さない。
      @failure_code = error.reason.to_s
      nil
    end

    def deliver(endpoint, destination, delivery, payload)
      body = payload.to_json

      begin
        response = post(endpoint, destination, body)
        delivery.response_status = response.code.to_i
        delivery.delivered_at = Time.current
      rescue StandardError => error
        # 宛先の不調で送信元が落ちないようにする。結果だけを記録する。
        delivery.error_message = error.message.truncate(200)
      end

      delivery.save!
    end

    def post(endpoint, destination, body)
      uri = destination.uri
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-OfficeWeave-Signature"] = endpoint.signature_for(body)
      request.body = body

      # 送るのは 1 回だけとする。3xx の Location へは追わない。
      # 追うと、検証を通した宛先から内部の宛先へ誘導できてしまう。
      build_connection(destination).start { |connection| connection.request(request) }
    end

    # 接続の組み立て。
    #
    # address には元のホスト名を渡す。Host ヘッダー、TLS の SNI、
    # 証明書のホスト名検証は、いずれもこの値を使う必要がある。
    # 接続先だけを検証済みの IP へ固定する。
    #
    # 第 3 引数へ nil を渡し、http_proxy などの環境変数を使わない。
    # proxy を経由すると、接続先を固定しても実際の宛先が proxy の判断で決まる。
    def build_connection(destination)
      uri = destination.uri

      http = Net::HTTP.new(uri.hostname, uri.port, nil)
      http.ipaddr = destination.ip_address
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.write_timeout = WRITE_TIMEOUT

      if uri.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.verify_hostname = true
      end

      http
    end
end
