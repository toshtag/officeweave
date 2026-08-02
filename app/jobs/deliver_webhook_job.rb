require "delegate"
require "net/http"
require "timeout"

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

  # 1 つの応答で受け取る byte の総量の上限。
  #
  # 使うのは応答の状態だけであり、ステータス行もヘッダーも本文も読み捨てる。
  # 上限は、そのすべてを合わせた受け取り量に掛ける。本文だけを数えると、
  # 宛先はヘッダーへ同じ量を積んで同じ負荷を作れる。
  #
  # 受け取りの合図として妥当な大きさより十分に大きく、
  # worker のメモリを脅かさない値にする。
  MAXIMUM_RESPONSE_BYTES = 64 * 1024

  # 上限を超えたときに記録へ残す文面。
  # 宛先も payload も入れない。記録は持ち出されることがある。
  RESPONSE_TOO_LARGE_MESSAGE = "応答が大きすぎます".freeze

  # 圧縮した応答を要求しない。
  #
  # 本文は読み捨てるため、圧縮しても得るものがない。一方で、展開を伴うと
  # 小さい応答から大きな確保が起きる。上限は受け取った byte に掛かるため、
  # 展開後の量には効かない。
  #
  # Net::HTTP は、こちらが指定しない場合に gzip と deflate を要求し、
  # 受け取った応答を自動で展開する。指定すればどちらも行わない。
  # 宛先が指定を無視して圧縮を返しても、展開はされない。
  ACCEPTED_ENCODING = "identity".freeze

  # 要求の開始から終了までの上限。
  #
  # 上の待ち時間は、いずれも 1 回の操作に効く。それより短い間隔で
  # 少しずつ返し続ける宛先は、どの上限にも掛からないまま worker を占有できる。
  # 経過そのものを測り、越えたところで打ち切る。
  #
  # 1 回の読み取りが止まった場合は READ_TIMEOUT の側で切れるよう、
  # それより長くする。逆にすると、一時的な停止までやり直さない失敗になる。
  TOTAL_DEADLINE = 30

  # 初回に加えて 4 回やり直す。合計 5 回まで実行する。
  MAXIMUM_ATTEMPTS = 5

  # やり直しの待ち時間。メールの送信と同じ間隔にそろえる。
  RETRY_INTERVALS = NotificationMailDeliveryJob::RETRY_INTERVALS

  # 時間を置けば通る可能性のある失敗。
  #
  # 宛先の検査による拒否は含めない。設定が変わらない限り結果も変わらない。
  # 恒久的な 4xx も含めない。受け取る側の実装が変わるまで通らない。
  class TransientDeliveryError < StandardError; end

  # 受け取る量が上限を超えたこと。
  #
  # 状態を受け取った後であれば、読み取りを打ち切るためだけに使い外へは出さない。
  # 状態を受け取る前に超えた場合は、送信の失敗として記録する。
  # やり直しはしない。同じ宛先は同じ量を返す。
  class ResponseTooLarge < StandardError
    def initialize(message = RESPONSE_TOO_LARGE_MESSAGE)
      super
    end
  end

  # 通信全体の期限を超えたこと。
  #
  # やり直す失敗には含めない。相手は応答を返し続けており、止まってはいない。
  # 期限に収まらないという結果は、やり直しても変わらない。
  # やり直すと、同じ占有を最大 5 回繰り返すことになる。
  class DeadlineExceeded < StandardError; end

  # ソケットから読む byte を数え、上限を超えたところで止める。
  #
  # Net::HTTP はステータス行とヘッダーを、応答をこちらへ渡す前に読み切る。
  # 読み終えてから大きさを見る形にすると、その時点で確保が済んでいる。
  # 一番外側の読み取りで数えれば、確保される前に止められる。
  #
  # 1 回の読み取りを残りの許容量までに切り詰める。抱える量が上限を超えない。
  class BoundedSocket < SimpleDelegator
    def initialize(io, limit)
      super(io)
      @remaining = limit
    end

    def read_nonblock(maximum, buffer = nil, exception: true)
      raise ResponseTooLarge if @remaining <= 0

      allowed = [ maximum, @remaining ].min
      result = if buffer
        __getobj__.read_nonblock(allowed, buffer, exception: exception)
      else
        __getobj__.read_nonblock(allowed, exception: exception)
      end

      @remaining -= result.bytesize if result.is_a?(String)
      result
    end
  end

  # 受け取る量に上限を持つ接続。
  #
  # Net::HTTP は、応答の読み取りの途中へ入る口を持たない。接続したソケットを
  # 包み、一番外側で数える。差し替えるのはこの接続の中だけであり、
  # Net::HTTP そのものへは手を入れない。
  #
  # TLS の handshake は接続の中で終わるため、この数には入らない。
  class BoundedConnection < Net::HTTP
    attr_accessor :receive_limit

    private
      def connect
        super
        @socket.instance_variable_set(:@io, BoundedSocket.new(@socket.io, receive_limit))
      end
  end

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

  # 名前解決、許可リスト、期限は、テストから差し替える。
  # インスタンスの中に閉じ、他のテストへ漏れる状態を作らない。
  attr_writer :resolver, :allowlist, :total_deadline

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

    def total_deadline
      @total_deadline || TOTAL_DEADLINE
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
      rescue DeadlineExceeded, ResponseTooLarge => error
        # どちらもやり直しても同じ結果になる。相手は返し続けており、
        # 止まってはいない。返す量も期限に収まらない点も、宛先の側で決まる。
        # 通信の失敗より先に受ける。StandardError へ落とすと意図が読めない。
        delivery.error_message = error.message
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
      # Accept-Encoding は組み立ての時点で渡す。後から入れ替えても、
      # Net::HTTP は自分で付けた要求として展開を行う。
      request = Net::HTTP::Post.new(uri, "Accept-Encoding" => ACCEPTED_ENCODING)
      request["Content-Type"] = "application/json"
      request["X-OfficeWeave-Signature"] = endpoint.signature_for(body)
      # やり直しても変わらない値を添える。受け取る側が重複を判別できるようにする。
      request["X-OfficeWeave-Delivery-Id"] = job_id
      request.body = body

      status = nil

      within_deadline do
        # 送るのは 1 回だけとする。3xx の Location へは追わない。
        # 追うと、検証を通した宛先から内部の宛先へ誘導できてしまう。
        build_connection(destination).start do |connection|
          connection.request(request) do |response|
            status = response.code.to_i
            discard_body(response)
          end
        end
      end

      status
    rescue ResponseTooLarge
      # 状態を受け取った後なら、打ち切りは送信の失敗ではない。
      # 受け取る前に超えた場合は、記録できる状態が無いため失敗として渡す。
      raise if status.nil?

      status
    end

    # 要求の開始から終了までを期限で囲む。
    #
    # 頭部の受信も本文の受信も、同じ期限の中に入れる。本文だけを数えると、
    # 頭部を少しずつ返す宛先が同じ占有を作れる。頭部の読み取りは
    # Net::HTTP の中にあり、こちらから途中へ入れない。
    #
    # 名前解決を子プロセスへ逃がしたのとは事情が違う。getaddrinfo は
    # C の中で止まり、別の実行単位から止められない。ソケットの読み取りは
    # 待っている間に割り込みを受け取れるため、同じ実行単位のまま打ち切れる。
    #
    # 送出する例外はこの階層のものにする。Timeout::Error のままだと、
    # やり直す通信の失敗に含まれてしまう。
    def within_deadline(&block)
      Timeout.timeout(total_deadline, DeadlineExceeded, "通信全体の期限を超えました", &block)
    end

    # 本文を読み捨てる。
    #
    # block を渡さずに応答を受け取ると、Net::HTTP は本文を最後まで
    # メモリへ読み込む。block を渡し、届いた分をその場で捨てる。
    #
    # 量の判定はここでは行わない。ソケットの側で数える。ここで数えると、
    # ステータス行とヘッダーが漏れ、しかも読み終えた後の判定になる。
    def discard_body(response)
      response.read_body { |_chunk| nil }
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

      http = BoundedConnection.new(uri.hostname, uri.port, nil)
      http.receive_limit = MAXIMUM_RESPONSE_BYTES
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
