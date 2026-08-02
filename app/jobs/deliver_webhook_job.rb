require "net/http"

# 出来事を宛先へ送る。
#
# 送信は要求の外で行う。宛先が応答しない場合に、
# 画面の操作がその待ち時間だけ止まらないようにする。
#
# 宛先の検査は保存時にも行うが、それだけでは足りない。
# 保存後に名前解決の結果が内部のアドレスへ変わると、保存時の検査は通り抜ける。
# そのため送信のたびに解決し直し、接続先をその結果へ固定する。
#
# 実行は at-least-once とする。
# 受け取った側が応答を返した直後に接続が切れた場合、同じ出来事が二度届くことがある。
# 受け取る側が重複を判別できるよう、やり直しても変わらない配信識別子を添える。
class DeliverWebhookJob < ApplicationJob
  queue_as :default

  # 宛先が応答しない場合に、いつまでも待たない。
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  WRITE_TIMEOUT = 10

  # 応答の本文を読む量の上限。
  #
  # 使うのは応答の状態だけであり、本文は読み捨てる。上限を設けないと、
  # 宛先が返した分だけをそのまま抱えることになる。
  # 受け取りの合図として妥当な大きさより十分に大きく、
  # worker のメモリを脅かさない値にする。
  MAXIMUM_RESPONSE_BYTES = 64 * 1024

  # 初回に加えて 4 回やり直す。合計 5 回まで実行する。
  MAXIMUM_ATTEMPTS = 5

  # やり直しの待ち時間。メールの送信と同じ間隔にそろえる。
  RETRY_INTERVALS = NotificationMailDeliveryJob::RETRY_INTERVALS

  # 時間を置けば通る可能性のある失敗。
  #
  # 宛先の検査による拒否は含めない。設定が変わらない限り結果も変わらない。
  # 恒久的な 4xx も含めない。受け取る側の実装が変わるまで通らない。
  class TransientDeliveryError < StandardError; end

  # 応答の本文が上限を超えたこと。
  #
  # 読み取りを打ち切るためだけに使い、この階層の外へは出さない。
  # 応答の状態は頭部で受け取り済みであり、送信の失敗ではない。
  class ResponseTooLarge < StandardError; end

  # やり直す応答。
  #
  # 408 要求の時間切れ、425 早すぎる再送、429 送信過多、5xx 受け取る側の不調。
  RETRYABLE_STATUSES = ([ 408, 425, 429 ] + (500..599).to_a).freeze

  # 通信そのものの失敗のうち、やり直す対象。
  TRANSIENT_NETWORK_ERRORS = [
    SocketError,
    IOError,
    SystemCallError,
    Timeout::Error,
    OpenSSL::SSL::SSLError
  ].freeze

  retry_on TransientDeliveryError,
           attempts: MAXIMUM_ATTEMPTS,
           wait: ->(executions) { RETRY_INTERVALS.fetch(executions - 1, RETRY_INTERVALS.last) }

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
      # 宛先が受け付けられない理由は、やり直しても変わらない。
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

    # 送信を試み、結果を記録する。
    #
    # 試行ごとに記録を残す。1 件へまとめると、何回試したかが分からない。
    # 一時的な失敗では、記録を残したうえで例外を送出してやり直しへ渡す。
    def deliver(endpoint, destination, delivery, payload)
      body = payload.to_json
      transient = nil

      begin
        status = post(endpoint, destination, body)
        delivery.response_status = status
        delivery.delivered_at = Time.current

        transient = "応答 #{status}" if RETRYABLE_STATUSES.include?(status)
      rescue *TRANSIENT_NETWORK_ERRORS => error
        delivery.error_message = error.message.truncate(200)
        transient = error.class.name
      rescue StandardError => error
        # 宛先の不調で送信元が落ちないようにする。結果だけを記録する。
        delivery.error_message = error.message.truncate(200)
      end

      delivery.save!

      # 例外の文面へ宛先や payload を入れない。記録として残り、持ち出されることがある。
      raise TransientDeliveryError, "送信をやり直します: #{transient}" if transient
    end

    # 送信し、応答の状態だけを返す。
    #
    # 応答そのものを返さない。本文は上限までしか読まないため、
    # 戻り値から本文へ触れる形にすると、読み切っていないものを
    # 読み切ったつもりで扱う経路ができる。
    def post(endpoint, destination, body)
      uri = destination.uri
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-OfficeWeave-Signature"] = endpoint.signature_for(body)
      # やり直しても変わらない値を添える。受け取る側が重複を判別できるようにする。
      request["X-OfficeWeave-Delivery-Id"] = job_id
      request.body = body

      status = nil

      # 送るのは 1 回だけとする。3xx の Location へは追わない。
      # 追うと、検証を通した宛先から内部の宛先へ誘導できてしまう。
      build_connection(destination).start do |connection|
        connection.request(request) do |response|
          status = response.code.to_i
          discard_body(response)
        end
      end

      status
    rescue ResponseTooLarge
      # 状態は頭部で受け取り済みである。打ち切りは失敗として扱わない。
      status
    end

    # 本文を読み捨てる。上限を超えた時点で読むのをやめる。
    #
    # block を渡さずに応答を受け取ると、Net::HTTP は本文を最後まで
    # メモリへ読み込む。block を渡し、届いた分の大きさだけを数える。
    # Content-Length の有無で経路を分けない。数えるのは届いた byte であり、
    # 申告された長さではない。chunked にも同じ上限が効く。
    #
    # 上限を超えたら例外で抜ける。block の中から抜けないと、
    # Net::HTTP が残りを読み切ってしまう。
    def discard_body(response)
      read = 0

      response.read_body do |chunk|
        read += chunk.bytesize
        raise ResponseTooLarge if read > MAXIMUM_RESPONSE_BYTES
      end
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
